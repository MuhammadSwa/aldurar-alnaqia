import 'dart:async';
import 'dart:io';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// ---------------------------------------------------------------------------
// Public API (main isolate)
// ---------------------------------------------------------------------------

const _kPrayerServiceEnabledKey = 'prayer_foreground_enabled';
const _kNotificationId = 988;
const _kChannelId = 'prayer_timing_channel';
const _kRouteHintKey = 'initial_route_hint';

/// Initializes and starts the foreground service that shows a persistent
/// notification with prayer timings and a live countdown for the next prayer.
///
/// Battery notes: the countdown itself is rendered natively by Android
/// (chronometer) so no timers run while idle; Dart code wakes up only at
/// prayer boundaries / midnight (~7 times a day).
Future<void> initializePrayerForegroundService() async {
  if (!Platform.isAndroid) return; // Only Android supports a foreground service

  final prefs = await SharedPreferences.getInstance();
  final enabled = prefs.getBool(_kPrayerServiceEnabledKey) ?? false;
  if (!enabled) return; // Respect user toggle

  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onStart,
      isForegroundMode: true,
      // Plugin's BootReceiver restarts us after reboot (RECEIVE_BOOT_COMPLETED
      // is merged from the plugin manifest).
      autoStart: true,
      notificationChannelId: _kChannelId,
      initialNotificationTitle: 'مواقيت الصلاة',
      initialNotificationContent: 'جارٍ التحديث...',
      foregroundServiceNotificationId: _kNotificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
    ),
  );

  // Ensure it is running
  await service.startService();
}

Future<void> setPrayerForegroundEnabled(bool enabled) async {
  if (!Platform.isAndroid) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kPrayerServiceEnabledKey, enabled);

  final service = FlutterBackgroundService();
  final isRunning = await service.isRunning();
  if (enabled && !isRunning) {
    await initializePrayerForegroundService();
  } else if (!enabled && isRunning) {
    // Ask the service to stop and wait briefly for it to shut down
    service.invoke('stopService');
    for (var i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!await service.isRunning()) break;
    }
  }
}

Future<bool> isPrayerForegroundEnabled() async {
  if (!Platform.isAndroid) return false;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kPrayerServiceEnabledKey) ?? false;
}

/// Re-computes and re-posts the persistent notification (location/method/
/// timezone settings changed). No-op while the service isn't running.
Future<void> refreshPrayerNotification() async {
  if (!Platform.isAndroid) return;
  try {
    FlutterBackgroundService().invoke('refresh');
  } catch (_) {
    // Not running; nothing to refresh.
  }
}

// ---------------------------------------------------------------------------
// Service isolate
// ---------------------------------------------------------------------------

final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
Timer? _updateTimer;

/// Entry point for the background isolate. Keep it TOP-LEVEL or STATIC.
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  _initTimezone();

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  // Stop handler: cancel pending work and remove the notification.
  service.on('stopService').listen((event) async {
    _updateTimer?.cancel();
    if (service is AndroidServiceInstance) {
      await service.stopSelf();
    }
  });

  // Manual refresh (settings changed, timezone changed, ...)
  service.on('refresh').listen((event) => _refresh(service));

  // Persist the tap-navigation hint ONCE here instead of on every update
  // tick (the old implementation wrote this pref every second!).
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRouteHintKey, '/timings');
  } catch (_) {}

  await _ensureChannel();
  await _refresh(service);
}

void _initTimezone() {
  try {
    tz_data.initializeTimeZones();
    SharedPreferences.getInstance().then((prefs) {
      final storedTz = prefs.getString('timezone') ?? '';
      if (storedTz.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(storedTz));
        // Location/timezone arrived after startup -> redraw once ready.
        FlutterBackgroundService().invoke('refresh');
      }
    }).catchError((_) {});
  } catch (_) {
    // ignore and use default
  }
}

Future<void> _ensureChannel() async {
  const channel = AndroidNotificationChannel(
    _kChannelId,
    'مواقيت الصلاة',
    description: 'إشعار دائم يعرض مواقيت الصلاة والعد التنازلي للصلاة التالية',
    importance: Importance.low, // Persistent, non-intrusive
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  try {
    await _fln.initialize(settings: initSettings);
    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  } catch (_) {
    // Notification rendering is best-effort; the FGS keeps its own basic
    // notification as fallback.
  }
}

// ---------------------------------------------------------------------------
// Computation
// ---------------------------------------------------------------------------

class _DayPlan {
  _DayPlan(this.rows, this.nextName, this.nextAt);

  /// Formatted "name time" rows for all prayers of the day.
  final List<String> rows;

  /// Arabic name of the upcoming prayer.
  final String nextName;

  /// Absolute local time of the upcoming prayer.
  final DateTime nextAt;
}

/// Computes today's schedule; returns null when location isn't configured.
Future<_DayPlan?> _computePlanAsync() async {
  final prefs = await SharedPreferences.getInstance();
  final lat = prefs.getDouble('latitude') ?? 0.0;
  final lng = prefs.getDouble('longitude') ?? 0.0;
  if (lat == 0.0 || lng == 0.0) return null;

  final method = prefs.getString('method') ?? 'egyptian';
  final asrCalc = prefs.getString('asrCalculation') ?? 'shafi';
  final highLatitudeRule =
      prefs.getString('highLatitudeRule') ?? 'middle_of_night';

  final coordinates = Coordinates(lat, lng);
  final params =
      _buildCalcParams(method, asrCalc, highLatitudeRule, lat);
  final now = tz.TZDateTime.now(tz.local);
  final prayers = PrayerTimes(
    coordinates: coordinates,
    date: now,
    calculationParameters: params,
    precision: true,
  );

  final entries = <(String, DateTime)>[
    ('الفجر', prayers.fajr),
    ('الشروق', prayers.sunrise),
    ('الظهر', prayers.dhuhr),
    ('العصر', prayers.asr),
    ('المغرب', prayers.maghrib),
    ('العشاء', prayers.isha),
  ];

  final nextPrayer = prayers.nextPrayer();
  var nextName = nextPrayer.name;
  var nextTime = prayers.timeForPrayer(nextPrayer);
  if (nextPrayer == Prayer.fajrAfter) nextName = 'fajr';

  final nextLocal = tz.TZDateTime.from(nextTime, tz.local);
  final nextArabic = _arabicPrayerName(nextName);

  // Expanded view: all six times, upcoming one highlighted.
  final highlighted = <String>[
    for (final (name, time) in entries)
      name == nextArabic
          ? '<b><font color="#2e7d32">$name ${_formatHm(time)}</font></b>'
          : '$name ${_formatHm(time)}',
  ];

  return _DayPlan(highlighted, nextArabic, nextLocal);
}

/// When should Dart next wake up?
///
///  * Just after the next prayer time (advance the countdown target), or
///  * just after local midnight (the displayed day schedule goes stale).
///
/// Either way it's a handful of wakeups per day. The visible countdown
/// itself keeps ticking accurately through Doze because the chronometer
/// counts down to an absolute timestamp rendered by the system.
DateTime _nextWakeUp(DateTime now, DateTime nextPrayerAt) {
  final midnight =
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  if (nextPrayerAt.isAfter(midnight)) {
    return midnight.add(const Duration(seconds: 5));
  }
  final fire = nextPrayerAt.add(const Duration(seconds: 2));
  return fire.isAfter(now) ? fire : now.add(const Duration(seconds: 2));
}

// ---------------------------------------------------------------------------
// Notification posting
// ---------------------------------------------------------------------------

Future<void> _refresh(ServiceInstance service) async {
  _updateTimer?.cancel();
  final now = tz.TZDateTime.now(tz.local);

  _DayPlan? plan;
  try {
    plan = await _computePlanAsync();
  } catch (_) {
    plan = null;
  }

  if (plan == null) {
    await _post(
      content: 'الرجاء ضبط الموقع لحساب المواقيت',
      bigTextHtml: 'الرجاء ضبط الموقع لحساب المواقيت',
      countdownTarget: null,
    );
    // Check again later (cheap one-shot; user probably hasn't set location yet).
    _updateTimer = Timer(
      const Duration(minutes: 15),
      () => _refresh(service),
    );
    return;
  }

  final diff = plan.nextAt.difference(now);
  await _post(
    content: 'الصلاة القادمة: ${plan.nextName}',
    bigTextHtml: '${plan.rows.join('<br>')}'
        '<br><b>${plan.nextName} بعد '
        '${_formatCountdown(diff.isNegative ? Duration.zero : diff)}</b>',
    countdownTarget: plan.nextAt.millisecondsSinceEpoch,
  );

  _updateTimer = Timer(
    _nextWakeUp(now, plan.nextAt).difference(now),
    () => _refresh(service),
  );
}

Future<void> _post({
  required String content,
  required String bigTextHtml,
  required int? countdownTarget,
}) async {
  final details = AndroidNotificationDetails(
    _kChannelId,
    'مواقيت الصلاة',
    channelDescription:
        'إشعار دائم يعرض مواقيت الصلاة والعد التنازلي للصلاة التالية',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    autoCancel: false,
    onlyAlertOnce: true,
    playSound: false,
    enableVibration: false,
    channelShowBadge: false,
    icon: 'ic_stat_prayer',
    color: const Color(0xFF2E7D32),
    // Native countdown: SystemUI ticks this itself, no app wakeups needed.
    when: countdownTarget,
    usesChronometer: countdownTarget != null,
    chronometerCountDown: true,
    styleInformation: BigTextStyleInformation(
      '\u202B$bigTextHtml\u202C',
      htmlFormatBigText: true,
      contentTitle: '\u202Bمواقيت الصلاة\u202C',
      summaryText: '\u202B$content\u202C',
    ),
  );

  try {
    await _fln.show(
      id: _kNotificationId,
      title: '\u202Bمواقيت الصلاة\u202C',
      body: '\u202B$content\u202C',
      notificationDetails: NotificationDetails(android: details),
    );
  } catch (_) {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// "4:05 ص" / "12:30 م"
String _formatHm(DateTime time) {
  final local = tz.TZDateTime.from(time, tz.local);
  final hourRaw = local.hour;
  final suffix = hourRaw < 12 ? 'ص' : 'م';
  final h = hourRaw % 12 == 0 ? 12 : hourRaw % 12;
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m $suffix';
}

/// "01:23:45" / "23:45" style remaining duration.
String _formatCountdown(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h == '00' ? '$m:$s' : '$h:$m:$s';
}

CalculationParameters _buildCalcParams(
    String method, String asrCalc, String highLatitudeRule, double lat) {
  CalculationParameters params;
  switch (method) {
    case 'egyptian':
      params = CalculationMethodParameters.egyptian();
      break;
    case 'karachi':
      params = CalculationMethodParameters.karachi();
      break;
    case 'muslim_world_league':
      params = CalculationMethodParameters.muslimWorldLeague();
      break;
    case 'dubai':
      params = CalculationMethodParameters.dubai();
      break;
    case 'qatar':
      params = CalculationMethodParameters.qatar();
      break;
    case 'kuwait':
      params = CalculationMethodParameters.kuwait();
      break;
    case 'turkey':
      params = CalculationMethodParameters.turkiye();
      break;
    case 'tehran':
      params = CalculationMethodParameters.tehran();
      break;
    case 'singapore':
      params = CalculationMethodParameters.singapore();
      break;
    case 'umm_al_qura':
      params = CalculationMethodParameters.ummAlQura();
      break;
    case 'north_america':
      params = CalculationMethodParameters.northAmerica();
      break;
    case 'moon_sighting_committee':
      params = CalculationMethodParameters.moonsightingCommittee();
      break;
    default:
      params = CalculationMethodParameters.other();
      break;
  }

  params.madhab = asrCalc == 'shafi' ? Madhab.shafi : Madhab.hanafi;

  if (lat.abs() > 48.0) {
    switch (highLatitudeRule) {
      case 'middle_of_night':
        params.highLatitudeRule = HighLatitudeRule.middleOfTheNight;
        break;
      case 'seventh_of_night':
        params.highLatitudeRule = HighLatitudeRule.seventhOfTheNight;
        break;
      case 'twilight_angle':
        params.highLatitudeRule = HighLatitudeRule.twilightAngle;
        break;
      default:
        params.highLatitudeRule = HighLatitudeRule.middleOfTheNight;
        break;
    }
  }

  return params;
}

String _arabicPrayerName(String englishName) {
  switch (englishName.toLowerCase()) {
    case 'fajr':
      return 'الفجر';
    case 'sunrise':
      return 'الشروق';
    case 'dhuhr':
      return 'الظهر';
    case 'asr':
      return 'العصر';
    case 'maghrib':
      return 'المغرب';
    case 'isha':
      return 'العشاء';
    default:
      return 'الفجر';
  }
}
