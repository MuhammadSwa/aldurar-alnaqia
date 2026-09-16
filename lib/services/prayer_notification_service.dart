import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart'
    show PrefsKeys, SharedPreferencesService;
import 'package:aldurar_alnaqia/common/helpers/logger.dart';

// ---------------------------------------------------------------------------
// Native prayer-notification bridge (Android only)
//
// The persistent prayer-times notification is implemented fully in native
// Kotlin (see android/.../PrayerNotificationService.kt). This file is the
// single Dart-side entry point: it requests the notification permission,
// persists the toggle + config, and forwards start/stop/refresh commands
// over the `app/prayer_notification` method channel. No Dart code runs
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
  // Single serialization path: typed settings -> native map. The native
  // service must never observe half-saved coordinates/timezone/method, so
  // all writers go through `savePrayerSettings` (one refresh per save).
  final settings = SharedPreferencesService.loadPrayerSettings();
  final map = settings.toNativeMap();
  await prefs.setString(
    PrefsKeys.prayerNativeConfig,
    jsonEncode({
      ...map,
      // Phase 5 policy flag: exact alarms only for alertable prayers.
      'preciseAlerts': prefs.getBool(PrefsKeys.prayerPreciseAlerts) ?? true,
    }),
  );
}

void _startNativeService() {
  try {
    _channel.invokeMethod<void>('start');
  } catch (e) {
    logWarn('prayer channel start failed: $e');
  }
}

/// Whether the native service has actually posted its notification.
Future<bool> isPrayerNotificationPosted() async {
  try {
    return await _channel.invokeMethod<bool>('isNotificationPosted') ?? false;
  } catch (_) {
    return false;
  }
}

/// Waits until the notification is actually shown/removed so the UI spinner
/// matches reality. [minDuration] keeps the spinner from flashing (SystemUI
/// can lag a bit behind the post on some OEMs).
Future<void> waitUntilPrayerNotificationState(
  bool target, {
  Duration timeout = const Duration(seconds: 8),
  Duration minDuration = const Duration(milliseconds: 800),
}) async {
  final sw = Stopwatch()..start();
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final posted = await isPrayerNotificationPosted();
    if (posted == target && sw.elapsed >= minDuration) return;
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
