import 'dart:async';
import 'dart:io';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/widgets.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan_dart/adhan_dart.dart';

// Initializes and starts the foreground service that shows a persistent
// notification with prayer timings and a live countdown for the next prayer.
const _kPrayerServiceEnabledKey = 'prayer_foreground_enabled';

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
      autoStart: true,
      notificationChannelId: 'prayer_timing_channel',
      initialNotificationTitle: 'مواقيت الصلاة',
      initialNotificationContent: 'جارٍ التحميل...',
      foregroundServiceNotificationId: 988,
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

// Entry point for the background isolate. Keep it TOP-LEVEL or STATIC.
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  // Initialize flutter binding for background isolate
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone setup: use stored timezone if available, fallback to local or UTC
  try {
    tz.initializeTimeZones();
    final prefs = await SharedPreferences.getInstance();
    final storedTz = prefs.getString('timezone') ?? '';
    if (storedTz.isNotEmpty) {
      tz.setLocalLocation(tz.getLocation(storedTz));
    }
  } catch (_) {
    // ignore and use default
  }

  // Ensure foreground mode and show immediately
  Timer? ticker;
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  // Stop handler: cancel ticker and remove notification by stopping service
  service.on('stopService').listen((event) async {
    ticker?.cancel();
    if (service is AndroidServiceInstance) {
      await service.stopSelf();
    }
  });

  // Manual refresh handler
  service.on('refresh').listen((event) async {
    await _pushNotificationUpdate(service);
  });

  // Immediate notification update
  await _pushNotificationUpdate(service);

  // Periodically update the foreground notification
  ticker = Timer.periodic(const Duration(seconds: 1), (timer) async {
    await _pushNotificationUpdate(service);
  });
}

Future<String> _buildNotificationContent() async {
  final prefs = await SharedPreferences.getInstance();

  final lat = prefs.getDouble('latitude') ?? 0.0;
  final lng = prefs.getDouble('longitude') ?? 0.0;
  final method = prefs.getString('method') ?? 'egyptian';
  final asrCalc = prefs.getString('asrCalculation') ?? 'shafi';
  final highLatitudeRule =
      prefs.getString('highLatitudeRule') ?? 'middle_of_night';

  final buffer = StringBuffer();

  if (lat == 0.0 || lng == 0.0) {
    buffer.write('الرجاء ضبط الموقع لحساب المواقيت');
    return buffer.toString();
  }

  try {
    final coordinates = Coordinates(lat, lng);
    final params = _buildCalcParams(method, asrCalc, highLatitudeRule, lat);
    final now = tz.TZDateTime.now(tz.local);
    final prayers = PrayerTimes(
      coordinates: coordinates,
      date: now,
      calculationParameters: params,
      precision: true,
    );

    // buffer.write(
    // 'فجر ${_formatHm(prayers.fajr)} • شروق ${_formatHm(prayers.sunrise)} • ظهر ${_formatHm(prayers.dhuhr)} • عصر ${_formatHm(prayers.asr)} • مغرب ${_formatHm(prayers.maghrib)} • عشاء ${_formatHm(prayers.isha)}');

    // Next prayer
    final nextPrayer = prayers.nextPrayer();
    String nextName = nextPrayer.name;
    DateTime nextTime = prayers.timeForPrayer(nextPrayer);
    if (nextPrayer == Prayer.fajrAfter) {
      nextTime = prayers.fajrAfter;
      nextName = 'fajr';
    }

    final localNext = tz.TZDateTime.from(nextTime, tz.local);
    final diff = localNext.difference(now);
    final visible = diff.isNegative ? Duration.zero : diff;
    final h = visible.inHours.toString().padLeft(2, '0');
    final m = (visible.inMinutes % 60).toString().padLeft(2, '0');
    final s = (visible.inSeconds % 60).toString().padLeft(2, '0');

    final arName = _arabicPrayerName(nextName);
    buffer.write('$arName بعد $h:$m:$s');

    return buffer.toString();
  } catch (_) {
    return 'تعذّر حساب المواقيت';
  }
}

String _toRtl(String s) => '\u202B$s\u202C';

Future<void> _pushNotificationUpdate(ServiceInstance service) async {
  final content = _toRtl(await _buildNotificationContent());
  if (service is AndroidServiceInstance) {
    // Many launchers open the app on notification tap by default.
    // To support direct navigation, we also store a hint flag.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('initial_route_hint', '/timings');
    await service.setForegroundNotificationInfo(
      title: _toRtl('مواقيت الصلاة'),
      content: content,
    );
  }
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
