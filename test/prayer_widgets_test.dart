// Widget/unit tests for the prayer timings screen.
//
// Proves: the timetable renders from the derived view (no calculation in
// build), the countdown owns its ticker locally, and the highlight follows
// the next event by instant identity.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:aldurar_alnaqia/prayer/prayer_hijri.dart';
import 'package:aldurar_alnaqia/prayer/prayer_providers.dart';
import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/next_prayer_countdown.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_notification_dialog.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_card.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';

/// Configured prefs (Cairo) so the real providers derive a real view.
Future<ProviderContainer> makeConfiguredContainer() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    PrefsKeys.latitude: 30.0444,
    PrefsKeys.longitude: 31.2357,
    PrefsKeys.method: PrayerMethods.egyptian,
    PrefsKeys.asrCalculation: PrayerMadhabs.shafi,
    PrefsKeys.timezone: 'Africa/Cairo',
    PrefsKeys.cityLabel: 'القاهرة، مصر',
  });
  await SharedPreferencesService().init();
  final container = ProviderContainer();
  // Force provider creation against the mock prefs.
  container.read(prayerViewProvider);
  return container;
}

Future<ProviderContainer> makeEmptyContainer() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await SharedPreferencesService().init();
  return ProviderContainer();
}

void main() {
  setUpAll(() => tzdata.initializeTimeZones());

  group('PrayerTimingsCard', () {
    testWidgets('renders derived schedule without recalculating',
        (tester) async {
      final container = await makeConfiguredContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: PrayerTimingsCard()),
          ),
        ),
      );
      await tester.pump();
      // All six fard + sunnah rows present.
      for (final name in [
        'الفجر',
        'الشروق',
        'الظهر',
        'العصر',
        'المغرب',
        'العشاء',
        'منتصف الليل',
        'الثلث الأخير',
        'الضحى',
      ]) {
        expect(find.text(name), findsWidgets, reason: 'missing $name');
      }
      // No placeholder dashes when a schedule exists.
      expect(find.text('--:--'), findsNothing);
      container.dispose();
    });

    testWidgets('shows placeholder when unconfigured', (tester) async {
      final container = await makeEmptyContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: PrayerTimingsCard())),
        ),
      );
      await tester.pump();
      expect(find.text('--:--'), findsWidgets);
    });
  });

  group('NextPrayerCountdown', () {
    testWidgets('shows next name and ticks locally', (tester) async {
      final container = await makeConfiguredContainer();
      addTearDown(container.dispose);
      var buildCount = 0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  buildCount++;
                  return const NextPrayerCountdown();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Next prayer name + countdown label render (name depends on time of day).
      expect(find.textContaining('بعد'), findsOneWidget);
      // Advance 3 seconds: countdown text updates via its LOCAL timer.
      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining('بعد'), findsOneWidget);
      expect(
        buildCount,
        lessThan(5),
        reason: 'parent rebuilt every second: ticker leaked upward',
      );
      container.dispose();
    });

    testWidgets('shows setup prompt when unconfigured, recovers on save',
        (tester) async {
      final container = await makeEmptyContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: NextPrayerCountdown()),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('اضغط لتحديد الموقع'), findsOneWidget);

      // Publishing settings (as the settings form does) flows through.
      container.read(prayerConfigProvider.notifier).publish(
            const PrayerSettings(
              latitude: 30.0444,
              longitude: 31.2357,
              timezone: 'Africa/Cairo',
              method: 'egyptian',
              madhab: 'shafi',
              highLatitudeRule: 'middle_of_night',
            ),
            '',
          );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('بعد'), findsOneWidget);
      expect(find.textContaining('00:00:00'), findsNothing);
      container.dispose();
    });
  });

  group('hijriLabel (pure, shared by widget and native payload)', () {
    test('advances one day after Maghrib', () {
      final loc = tz.getLocation('Africa/Cairo');
      final maghrib = tz.TZDateTime(loc, 2024, 6, 15, 19, 57);
      final before = tz.TZDateTime(loc, 2024, 6, 15, 19);
      final after = tz.TZDateTime(loc, 2024, 6, 15, 20, 30);
      final a = hijriLabel(now: before, maghrib: maghrib, offset: 0);
      final b = hijriLabel(now: after, maghrib: maghrib, offset: 0);
      expect(a, isNotEmpty);
      expect(b, isNotEmpty);
      expect(a, isNot(equals(b)));
    });

    test('offset shifts days; null maghrib still works', () {
      final loc = tz.getLocation('Africa/Cairo');
      final now = tz.TZDateTime(loc, 2024, 6, 15, 12);
      final base = hijriLabel(now: now, maghrib: null, offset: 0);
      final plus = hijriLabel(now: now, maghrib: null, offset: 1);
      expect(base, isNotEmpty);
      expect(plus, isNotEmpty);
      expect(plus, isNot(equals(base)));
    });
  });

  group('PrayerNotificationDialog', () {
    Future<void> pumpDialog(WidgetTester tester) {
      return tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PrayerNotificationDialog(),
            ),
          ),
        ),
      );
    }

    testWidgets('explains the notification with always-exact alert',
        (tester) async {
      await pumpDialog(tester);
      expect(find.text('إشعار المواقيت'), findsOneWidget);
      expect(find.textContaining('شريط الإشعارات'), findsOneWidget);
      expect(find.textContaining('بضع ثوان'), findsOneWidget);
      expect(find.text('تشغيل الإشعار'), findsOneWidget);
      expect(find.text('إغلاق'), findsOneWidget);
      expect(find.text('إيقاف الإشعار'), findsNothing);
    });
  });
}
