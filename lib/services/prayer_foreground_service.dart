import 'dart:async';
import 'dart:io';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
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
  Timer? _ticker;
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  // Stop handler: cancel ticker and remove notification by stopping service
  service.on('stopService').listen((event) async {
    _ticker?.cancel();
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
  _ticker = Timer.periodic(const Duration(seconds: 1), (timer) async {
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

    String formatHM(DateTime? dt) {
      if (dt == null) return '--:--';
      final tzdt = tz.TZDateTime.from(dt, tz.local);
      final h = tzdt.hour.toString().padLeft(2, '0');
      final m = tzdt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    // buffer.write('فجر ${formatHM(prayers.fajr)} • شروق ${formatHM(prayers.sunrise)} • ظهر ${formatHM(prayers.dhuhr)} • عصر ${formatHM(prayers.asr)} • مغرب ${formatHM(prayers.maghrib)} • عشاء ${formatHM(prayers.isha)}');

    // Next prayer
    String nextName = prayers.nextPrayer();
    DateTime? nextTime = prayers.timeForPrayer(nextName);
    if (nextName == 'fajrafter') {
      nextTime = prayers.fajrafter;
      nextName = 'fajr';
    }

    if (nextTime != null) {
      final localNext = tz.TZDateTime.from(nextTime, tz.local);
      final diff = localNext.difference(now);
      final visible = diff.isNegative ? Duration.zero : diff;
      final h = visible.inHours.toString().padLeft(2, '0');
      final m = (visible.inMinutes % 60).toString().padLeft(2, '0');
      final s = (visible.inSeconds % 60).toString().padLeft(2, '0');

      final arName = _arabicPrayerName(nextName);
      buffer.write('  •  التالي: $arName بعد $h:$m:$s');
    }

    return buffer.toString();
  } catch (_) {
    return 'تعذّر حساب المواقيت';
  }
}

Future<void> _pushNotificationUpdate(ServiceInstance service) async {
  final content = await _buildNotificationContent();
  if (service is AndroidServiceInstance) {
    // Many launchers open the app on notification tap by default.
    // To support direct navigation, we also store a hint flag.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('initial_route_hint', '/timings');
    await service.setForegroundNotificationInfo(
      title: 'مواقيت الصلاة',
      content: content,
    );
  }
}

CalculationParameters _buildCalcParams(
    String method, String asrCalc, String highLatitudeRule, double lat) {
  CalculationParameters params;
  switch (method) {
    case 'egyptian':
      params = CalculationMethod.egyptian();
      break;
    case 'karachi':
      params = CalculationMethod.karachi();
      break;
    case 'muslim_world_league':
      params = CalculationMethod.muslimWorldLeague();
      break;
    case 'dubai':
      params = CalculationMethod.dubai();
      break;
    case 'qatar':
      params = CalculationMethod.qatar();
      break;
    case 'kuwait':
      params = CalculationMethod.kuwait();
      break;
    case 'turkey':
      params = CalculationMethod.turkiye();
      break;
    case 'tehran':
      params = CalculationMethod.tehran();
      break;
    case 'singapore':
      params = CalculationMethod.singapore();
      break;
    case 'umm_al_qura':
      params = CalculationMethod.ummAlQura();
      break;
    case 'north_america':
      params = CalculationMethod.northAmerica();
      break;
    case 'moon_sighting_committee':
      params = CalculationMethod.moonsightingCommittee();
      break;
    default:
      params = CalculationMethod.other();
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
