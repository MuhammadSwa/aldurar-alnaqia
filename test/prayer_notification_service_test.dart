import 'dart:convert';

import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart'
    show PrayerMadhabs, PrayerMethods;
import 'package:aldurar_alnaqia/services/prayer_notification_service.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart'
    show PrefsKeys, SharedPreferencesService;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final channelCalls = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferencesService().init();
    channelCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('app/prayer_notification'),
      (call) async {
        channelCalls.add(call.method);
        return null;
      },
    );
  });

  group('toggle persistence', () {
    test('disabled by default', () async {
      expect(await isPrayerNotificationEnabled(), isFalse);
    });

    test('set round-trips the toggle', () async {
      await setPrayerNotificationEnabled(true);
      expect(await isPrayerNotificationEnabled(), isTrue);
      await setPrayerNotificationEnabled(false);
      expect(await isPrayerNotificationEnabled(), isFalse);
    });

    test('enabling starts the native service, disabling stops it', () async {
      await setPrayerNotificationEnabled(true);
      expect(channelCalls, contains('start'));
      await setPrayerNotificationEnabled(false);
      expect(channelCalls, contains('stop'));
    });
  });

  group('refreshPrayerNotification', () {
    test('writes the native config JSON for the saved settings', () async {
      await SharedPreferencesService.savePrayerSettings(
        latitude: 30.0444,
        longitude: 31.2357,
        method: PrayerMethods.karachi,
        asrCalculation: PrayerMadhabs.hanafi,
        timezone: 'Africa/Cairo',
      );
      channelCalls.clear();

      await refreshPrayerNotification();

      expect(channelCalls, contains('refresh'));
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(PrefsKeys.prayerNativeConfig);
      expect(raw, isNotNull);
      final config = jsonDecode(raw!) as Map<String, dynamic>;
      expect(config['lat'], 30.0444);
      expect(config['lng'], 31.2357);
      expect(config['method'], PrayerMethods.karachi);
      expect(config['asrCalculation'], PrayerMadhabs.hanafi);
      expect(config['timezone'], 'Africa/Cairo');
      expect(config['version'], isNotNull);
      expect(config.containsKey('hijriOffset'), isFalse);
      // Contract v3: precomputed tables ride along, with Hijri labels.
      expect((config['days'] as List).length, 30);
      expect((config['midnights'] as List).length, 31);
      final day = (config['days'] as List).first as Map;
      expect((day['hb'] as String).isNotEmpty, isTrue);
      expect((day['ha'] as String).isNotEmpty, isTrue);
    });

    test('empty prefs write defaults without throwing', () async {
      await refreshPrayerNotification();

      final prefs = await SharedPreferences.getInstance();
      final config =
          jsonDecode(prefs.getString(PrefsKeys.prayerNativeConfig)!)
              as Map<String, dynamic>;
      expect(config['method'], PrayerMethods.egyptian);
      expect(config['timezone'], isEmpty);
      expect(config['days'] as List, isEmpty);
      expect(config['midnights'] as List, isEmpty);
    });
  });

  group('initializePrayerNotifications', () {
    test('is a safe no-op off Android', () async {
      await initializePrayerNotifications();
      await initializePrayerNotifications();
      // No permission prompt, no channel traffic on desktop/test hosts.
      expect(channelCalls, isEmpty);
    });
  });

  group('onNotificationRouteTap', () {
    test('is a broadcast stream', () {
      expect(onNotificationRouteTap.isBroadcast, isTrue);
    });
  });
}
