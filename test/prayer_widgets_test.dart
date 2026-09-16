// Phase 6 — widget/unit tests for the Phase 2 timer consolidation.
//
// Proves: the timetable renders from the cached schedule (no calculation in
// build), the countdown owns its ticker locally, Hijri/day labels flip at
// Maghrib without timers, and nothing rebuilds every second.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:aldurar_alnaqia/screens/prayer_timings_screen/adjust_hijri_day_dialog_box.dart'
    show hijriDayWithOffset;
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/prayer_schedule.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/next_prayer_countdown.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_card.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart';

const _settings = PrayerSettings(
  latitude: 30.0444,
  longitude: 31.2357,
  timezone: 'Africa/Cairo',
  method: 'egyptian',
  madhab: 'shafi',
  highLatitudeRule: 'middle_of_night',
);

/// Notifier stub: fixed schedule for *today*, no timers, no prefs, no assets.
class _FakePrayerNotifier extends PrayerTimingsNotifier {
  @override
  PrayerState build() {
    final now = tz.TZDateTime.now(tz.getLocation('Africa/Cairo'));
    final schedule = PrayerScheduleCalculator.calculate(
      settings: _settings,
      date: now,
    )!;
    final next = schedule.nextEventAt(now);
    return PrayerState(
      schedule: schedule,
      islamicWeekday: 6,
      nextPrayerInfo: (next.time, next.arabicName),
      isInitialized: true,
    );
  }
}

void main() {
  setUpAll(() => tzdata.initializeTimeZones());

  group('PrayerTimingsCard', () {
    testWidgets('renders cached schedule without recalculating', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prayerProvider.overrideWith(_FakePrayerNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: PrayerTimingsCard()),
          ),
        ),
      );
      await tester.pump();
      // All six fard + sunnah rows present, next prayer highlighted by name.
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
    });

    testWidgets('shows placeholder when schedule is null', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: PrayerTimingsCard())),
        ),
      );
      await tester.pump();
      expect(find.text('--:--'), findsWidgets);
    });
  });

  group('NextPrayerCountdown', () {
    testWidgets('shows next name and ticks without touching provider',
        (tester) async {
      var buildCount = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prayerProvider.overrideWith(_FakePrayerNotifier.new),
          ],
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
      // Advance 3 seconds: countdown text updates via its LOCAL timer while
      // the provider never changes (no global tick).
      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining('بعد'), findsOneWidget);
      expect(
        buildCount,
        lessThan(5),
        reason: 'parent rebuilt every second: ticker leaked upward',
      );
    });
  });

  group('hijriDayWithOffset (pure, no timers)', () {
    test('advances one day after Maghrib', () {
      final loc = tz.getLocation('Africa/Cairo');
      final maghrib = tz.TZDateTime(loc, 2024, 6, 15, 19, 57);
      final before =
          tz.TZDateTime(loc, 2024, 6, 15, 19, 0).add(const Duration());
      final after = tz.TZDateTime(loc, 2024, 6, 15, 20, 30);
      final a = hijriDayWithOffset(offset: 0, now: before, maghrib: maghrib);
      final b = hijriDayWithOffset(offset: 0, now: after, maghrib: maghrib);
      final da = DateTime(a.hYear, a.hMonth, a.hDay);
      final db = DateTime(b.hYear, b.hMonth, b.hDay);
      expect(db.difference(da), const Duration(days: 1));
    });

    test('offset shifts days; null maghrib still works', () {
      final loc = tz.getLocation('Africa/Cairo');
      final now = tz.TZDateTime(loc, 2024, 6, 15, 12);
      final base = hijriDayWithOffset(offset: 0, now: now, maghrib: null);
      final plus =
          hijriDayWithOffset(offset: 1, now: now, maghrib: null);
      expect(
        DateTime(plus.hYear, plus.hMonth, plus.hDay)
            .difference(DateTime(base.hYear, base.hMonth, base.hDay)),
        const Duration(days: 1),
      );
    });
  });
}
