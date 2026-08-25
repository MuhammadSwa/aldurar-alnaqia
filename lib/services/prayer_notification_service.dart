import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Native prayer-notification bridge (Android only)
//
// The persistent prayer-times notification is implemented fully in native
// Kotlin (see android/.../PrayerNotificationService.kt). This file is a thin
// bridge: it persists the toggle + config and forwards start/stop/refresh
// commands over the `app/prayer_notification` method channel. No Dart code
// runs while the app UI is closed.
// ---------------------------------------------------------------------------

const _kEnabledKey = 'prayer_foreground_enabled';
const _kConfigKey = 'prayer_native_config';

/// Stream of routes requested by tapping the native notification.
Stream<String> get onNotificationRouteTap =>
    _routeTaps.stream;

final StreamController<String> _routeTaps =
    StreamController<String>.broadcast();

final MethodChannel _channel = MethodChannel('app/prayer_notification');

bool _initialized = false;

/// Registers the channel handler and starts the service when enabled.
/// Safe to call multiple times.
Future<void> initializePrayerForegroundService() async {
  if (!Platform.isAndroid) return;
  if (_initialized) return;
  _initialized = true;

  _channel.setMethodCallHandler((call) async {
    if (call.method == 'openRoute' && call.arguments is String) {
      final route = call.arguments as String;
      if (route.isNotEmpty) _routeTaps.add(route);
    }
  });

  await refreshPrayerNotification();
  if (await isPrayerForegroundEnabled()) {
    try {
      await _channel.invokeMethod<void>('dartReady');
    } catch (_) {}
    await startPrayerNotification();
  }
}

Future<void> startPrayerNotification() async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod<void>('start');
  } catch (_) {}
}

Future<void> setPrayerForegroundEnabled(bool enabled) async {
  if (!Platform.isAndroid) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kEnabledKey, enabled);
  await refreshPrayerNotification();
  if (enabled) {
    await startPrayerNotification();
  } else {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }
}

Future<bool> isPrayerForegroundEnabled() async {
  if (!Platform.isAndroid) return false;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kEnabledKey) ?? false;
}

/// Persists the current settings as JSON for the native service and asks it
/// to re-post the notification. Cheap no-op when the service isn't running.
Future<void> refreshPrayerNotification() async {
  if (!Platform.isAndroid) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConfigKey, jsonEncode({
      'lat': prefs.getDouble('latitude') ?? 0.0,
      'lng': prefs.getDouble('longitude') ?? 0.0,
      'method': prefs.getString('method') ?? 'egyptian',
      'asrCalculation': prefs.getString('asrCalculation') ?? 'shafi',
      'highLatitudeRule': prefs.getString('highLatitudeRule') ??
          'middle_of_night',
      'timezone': prefs.getString('timezone') ?? '',
    }));
    await _channel.invokeMethod<void>('refresh');
  } catch (_) {}
}
