import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aldurar_alnaqia/common/helpers/logger.dart';
import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart'
    show buildNativeConfigMap;
import 'package:aldurar_alnaqia/services/shared_prefs.dart'
    show PrefsKeys, SharedPreferencesService;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

// ---------------------------------------------------------------------------
// Native prayer-notification bridge (Android only)
//
// Dart owns all prayer math (adhan_dart via `PrayerScheduleCalculator`).
// The native Kotlin service (`PrayerNotificationService.kt`) is a dumb
// renderer + AlarmManager scheduler: it reads precomputed epoch-ms
// timetables from the config JSON and performs no solar calculation, so it
// keeps working while the Dart VM is killed. No Dart code runs
// while the app UI is closed.
// ---------------------------------------------------------------------------

const MethodChannel _channel = MethodChannel('app/prayer_notification');

final StreamController<String> _routeTaps =
    StreamController<String>.broadcast();

/// Stream of routes requested by tapping the native notification.
Stream<String> get onNotificationRouteTap => _routeTaps.stream;

bool _initialized = false;

/// Requests the notification permission, registers the channel handler and
/// starts the service when enabled. Safe to call multiple times.
Future<void> initializePrayerNotifications() async {
  if (!Platform.isAndroid) return;
  if (_initialized) return;
  _initialized = true;

  _channel.setMethodCallHandler((call) async {
    if (call.method == 'openRoute' && call.arguments is String) {
      final route = call.arguments as String;
      if (route.isNotEmpty) _routeTaps.add(route);
    }
  });

  final status = await Permission.notification.status;
  if (!status.isGranted) await Permission.notification.request();

  await _writeConfig();
  if (await isPrayerNotificationEnabled()) {
    try {
      // Flush a buffered cold-start notification tap, if any.
      await _channel.invokeMethod<void>('dartReady');
    } catch (e) {
      logWarn('prayer channel dartReady failed: $e');
    }
    _startNativeService();
  }
}

Future<bool> isPrayerNotificationEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(PrefsKeys.prayerForegroundEnabled) ?? false;
}

Future<void> setPrayerNotificationEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(PrefsKeys.prayerForegroundEnabled, enabled);
  await _writeConfig();
  if (enabled) {
    _startNativeService();
  } else {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (e) {
      logWarn('prayer channel stop failed: $e');
    }
  }
}

/// Persists the current settings as JSON for the native service and asks it
/// to re-post the notification. Cheap no-op when the service isn't running.
Future<void> refreshPrayerNotification() async {
  await _writeConfig();
  try {
    await _channel.invokeMethod<void>('refresh');
  } catch (e) {
    logWarn('prayer channel refresh failed: $e');
  }
}

Future<void> _writeConfig() async {
  final prefs = await SharedPreferences.getInstance();
  // Single serialization path: stored settings + precomputed timetables ->
  // native map. Writers (prayer `savePrayerSettings`, hijri offset changes)
  // save first, then call `refreshPrayerNotification`, so the native service
  // never observes half-saved coordinates/timezone/method. Policy is
  // always-exact: alertable prayers wake the device on time.
  // tz init is idempotent; main() already ran it, this covers test hosts.
  try {
    tzdata.initializeTimeZones();
  } catch (_) {}
  final settings = SharedPreferencesService.loadPrayerSettings();
  await prefs.setString(
    PrefsKeys.prayerNativeConfig,
    jsonEncode(
      buildNativeConfigMap(
        settings,
        hijriOffset: SharedPreferencesService.getHijriDayOffset(),
      ),
    ),
  );
}

void _startNativeService() {
  try {
    unawaited(_channel.invokeMethod<void>('start'));
  } catch (e) {
    logWarn('prayer channel start failed: $e');
  }
}
