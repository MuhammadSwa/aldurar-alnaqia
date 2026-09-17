// Native payload + regression fixtures for the prayer domain.
//
// Dart is the single source of prayer math (adhan_dart); Kotlin only renders
// precomputed tables (contract v2, see `buildNativeConfigMap`). Golden
// epoch-ms values below were produced by `PrayerScheduleCalculator`
// (adhan_dart 2.0.1) for the stated civil dates. Allow ±60s tolerance for
// library rounding; larger drift fails.
//
// Covers: Cairo, Makkah, Karachi, London, NYC DST transition, both madhabs,
// boundary selection, after-Isha→tomorrow-Fajr, Maghrib Islamic-day flip,
// invalid-config rejection, sunrise-never-alertable, native payload shape.

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:aldurar_alnaqia/common/helpers/islamic_date.dart'
    as islamic_date;
import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart';

const _cairo = PrayerSettings(
  latitude: 30.0444,
  longitude: 31.2357,
  timezone: 'Africa/Cairo',
  method: 'egyptian',
  madhab: 'shafi',
  highLatitudeRule: 'middle_of_night',
);

PrayerSchedule _sched(PrayerSettings s, DateTime date) {
  final schedule =
      PrayerScheduleCalculator.calculate(settings: s, date: date);
  assert(schedule != null, 'schedule unexpectedly null for $s');
  return schedule!;
}

void _expectGolden(
  PrayerSchedule s,
  Map<PrayerEventId, int> golden, {
  int toleranceMs = 60000,
}) {
  for (final entry in golden.entries) {
    final actual = s.events[entry.key]!.time.millisecondsSinceEpoch;
    expect(
      (actual - entry.value).abs() <= toleranceMs,
      isTrue,
      reason: '${entry.key.name}: actual $actual vs golden ${entry.value}',
    );
  }
}

void main() {
  setUpAll(() => tzdata.initializeTimeZones());

  group('golden fixtures (contract v$prayerConfigVersion)', () {
    test('Cairo 2024-06-15 egyptian/shafi', () {
      final s = _sched(_cairo, DateTime.utc(2024, 6, 15));
      _expectGolden(s, {
        PrayerEventId.fajr: 1718413652000,
        PrayerEventId.sunrise: 1718420009000,
        PrayerEventId.dhuhr: 1718445399000,
        PrayerEventId.asr: 1718458279000,
        PrayerEventId.maghrib: 1718470673000,
        PrayerEventId.isha: 1718476282000,
      });
      expect(s.tomorrowFajr.millisecondsSinceEpoch, 1718500054000);
    });

    test('Cairo tomorrow Fajr', () {
      final s = _sched(_cairo, DateTime.utc(2024, 6, 15));
      // 2024-06-16 01:07:34Z
      expect(
        (s.tomorrowFajr.millisecondsSinceEpoch - 1718500054000).abs() <= 60000,
        isTrue,
      );
    });

    test('Makkah 2024-06-15 umm_al_qura', () {
      final s = _sched(
        const PrayerSettings(
          latitude: 21.4225,
          longitude: 39.8262,
          timezone: 'Asia/Riyadh',
          method: 'umm_al_qura',
          madhab: 'shafi',
          highLatitudeRule: 'middle_of_night',
        ),
        DateTime.utc(2024, 6, 15),
      );
      _expectGolden(s, {
        PrayerEventId.fajr: 1718413823000,
        PrayerEventId.sunrise: 1718419098000,
        PrayerEventId.dhuhr: 1718443277000,
        PrayerEventId.asr: 1718455253000,
        PrayerEventId.maghrib: 1718467458000,
        PrayerEventId.isha: 1718472858000,
      });
    });

    test('Karachi 2024-06-15 hanafi', () {
      final s = _sched(
        const PrayerSettings(
          latitude: 24.8607,
          longitude: 67.0011,
          timezone: 'Asia/Karachi',
          method: 'karachi',
          madhab: 'hanafi',
          highLatitudeRule: 'middle_of_night',
        ),
        DateTime.utc(2024, 6, 15),
      );
      _expectGolden(s, {
        PrayerEventId.fajr: 1718406800000,
        PrayerEventId.sunrise: 1718412140000,
        PrayerEventId.dhuhr: 1718436814000,
        PrayerEventId.asr: 1718453716000,
        PrayerEventId.maghrib: 1718461372000,
        PrayerEventId.isha: 1718466715000,
      });
    });

    test('London 2024-06-15 high-latitude rule applied', () {
      final s = _sched(
        const PrayerSettings(
          latitude: 51.5074,
          longitude: -0.1278,
          timezone: 'Europe/London',
          method: 'muslim_world_league',
          madhab: 'shafi',
          highLatitudeRule: 'middle_of_night',
        ),
        DateTime.utc(2024, 6, 15),
      );
      _expectGolden(s, {
        PrayerEventId.fajr: 1718409675000,
        PrayerEventId.sunrise: 1718422962000,
        PrayerEventId.dhuhr: 1718452928000,
        PrayerEventId.asr: 1718468633000,
        PrayerEventId.maghrib: 1718482785000,
        PrayerEventId.isha: 1718496072000,
      });
    });

    test('NYC DST-start day 2024-03-10 advances', () {
      final s = _sched(
        const PrayerSettings(
          latitude: 40.7128,
          longitude: -74.006,
          timezone: 'America/New_York',
          method: 'north_america',
          madhab: 'shafi',
          highLatitudeRule: 'middle_of_night',
        ),
        DateTime.utc(2024, 3, 10),
      );
      _expectGolden(s, {
        PrayerEventId.fajr: 1710064801000,
        PrayerEventId.sunrise: 1710069293000,
        PrayerEventId.dhuhr: 1710090425000,
        PrayerEventId.asr: 1710102267000,
        PrayerEventId.maghrib: 1710111477000,
        PrayerEventId.isha: 1710115980000,
      });
    });

    test('hanafi Asr is later than shafi Asr', () {
      final d = DateTime.utc(2024, 6, 15);
      final shafi = _sched(_cairo, d);
      final hanafi = _sched(_cairo.copyWith(madhab: 'hanafi'), d);
      expect(
        hanafi.events[PrayerEventId.asr]!.time
            .isAfter(shafi.events[PrayerEventId.asr]!.time),
        isTrue,
      );
      expect(
        hanafi.events[PrayerEventId.asr]!.time.millisecondsSinceEpoch,
        1718462932000,
      );
    });
  });

  group('ordering + next-event selection', () {
    test('events are strictly ordered fajr..isha', () {
      final s = _sched(_cairo, DateTime.utc(2024, 6, 15));
      final ordered = s.ordered.map((e) => e.time).toList();
      for (var i = 1; i < ordered.length; i++) {
        expect(
          ordered[i].isAfter(ordered[i - 1]),
          isTrue,
          reason: 'event $i not after ${i - 1}',
        );
      }
    });

    test('before/at/after each boundary selects correctly', () {
      final s = _sched(_cairo, DateTime.utc(2024, 6, 15));
      final loc = tz.getLocation('Africa/Cairo');
      PrayerEventId nextAt(DateTime t) =>
          s.nextEventAt(tz.TZDateTime.from(t, loc)).id;

      expect(nextAt(DateTime.utc(2024, 6, 15, 0, 30)), PrayerEventId.fajr);
      // Just after Fajr (01:07:32Z) -> sunrise.
      expect(nextAt(DateTime.utc(2024, 6, 15, 1, 8)), PrayerEventId.sunrise);
      expect(nextAt(DateTime.utc(2024, 6, 15, 5)), PrayerEventId.dhuhr);
      expect(nextAt(DateTime.utc(2024, 6, 15, 10)), PrayerEventId.asr);
      expect(nextAt(DateTime.utc(2024, 6, 15, 15)), PrayerEventId.maghrib);
      expect(nextAt(DateTime.utc(2024, 6, 15, 17)), PrayerEventId.isha);
      // After Isha (18:31:22Z) -> tomorrow's Fajr.
      final afterIsha = s.nextEventAt(
          tz.TZDateTime.from(DateTime.utc(2024, 6, 15, 19), loc),);
      expect(afterIsha.id, PrayerEventId.fajr);
      expect(afterIsha.time, s.tomorrowFajr);
    });

    test('sunrise is never a prayer (no adhan alert)', () {
      final s = _sched(_cairo, DateTime.utc(2024, 6, 15));
      expect(s.events[PrayerEventId.sunrise]!.isPrayer, isFalse);
      for (final id in PrayerEventId.values) {
        if (id == PrayerEventId.sunrise) continue;
        expect(s.events[id]!.isPrayer, isTrue);
      }
    });

    test('Maghrib flips the Islamic weekday', () {
      final s = _sched(_cairo, DateTime.utc(2024, 6, 15));
      final before = s.maghrib.subtract(const Duration(minutes: 1));
      final after = s.maghrib.add(const Duration(minutes: 1));
      final effBefore =
          islamic_date.islamicEffectiveDate(now: before, maghrib: s.maghrib);
      final effAfter =
          islamic_date.islamicEffectiveDate(now: after, maghrib: s.maghrib);
      // Islamic day advances at Maghrib: same civil day, next effective day.
      DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
      expect(dayOf(effAfter).difference(dayOf(effBefore)), const Duration(days: 1));
    });

    test('sunnah times: night split + duha', () {
      final s = _sched(_cairo, DateTime.utc(2024, 6, 15));
      final sunnah = s.sunnah!;
      expect(
        sunnah.middleOfNight.isAfter(s.maghrib) &&
            sunnah.middleOfNight.isBefore(s.tomorrowFajr),
        isTrue,
      );
      expect(
        sunnah.lastThirdOfNight.isAfter(sunnah.middleOfNight) &&
            sunnah.lastThirdOfNight.isBefore(s.tomorrowFajr),
        isTrue,
      );
      expect(
        sunnah.duha, s.events[PrayerEventId.sunrise]!.time.add(const Duration(minutes: 20)),
      );
    });
  });

  group('invalid config is rejected visibly', () {
    test('unknown method returns null (no silent OTHER)', () {
      expect(
        PrayerScheduleCalculator.calculate(
          settings: _cairo.copyWith(method: 'not_a_method'),
          date: DateTime.utc(2024, 6, 15),
        ),
        isNull,
      );
    });

    test('unknown madhab returns null', () {
      expect(
        PrayerScheduleCalculator.calculate(
          settings: _cairo.copyWith(madhab: 'maliki'),
          date: DateTime.utc(2024, 6, 15),
        ),
        isNull,
      );
    });

    test('empty timezone / zero coords return null', () {
      expect(
        PrayerScheduleCalculator.calculate(
          settings: _cairo.copyWith(timezone: ''),
          date: DateTime.utc(2024, 6, 15),
        ),
        isNull,
      );
      expect(
        PrayerScheduleCalculator.calculate(
          settings: const PrayerSettings(
            latitude: 0,
            longitude: 0,
            timezone: 'Africa/Cairo',
            method: 'egyptian',
            madhab: 'shafi',
            highLatitudeRule: 'middle_of_night',
          ),
          date: DateTime.utc(2024, 6, 15),
        ),
        isNull,
      );
    });

    test('native map round-trip preserves settings', () {
      final restored = PrayerSettings.fromNativeMap(_cairo.toNativeMap());
      expect(restored.fingerprint, _cairo.fingerprint);
      expect(restored.validate(), isNull);
    });

    test('native payload precomputes 30 days + 31 midnights', () {
      final payload = buildNativeConfigMap(
        _cairo,
        now: DateTime.utc(2024, 6, 15, 12),
      );
      expect(payload['version'], prayerConfigVersion);
      final days = payload['days'] as List;
      final midnights = payload['midnights'] as List;
      expect(days.length, nativePrecomputeDays);
      expect(midnights.length, nativePrecomputeDays + 1);
      // Day 1 matches the golden fixture.
      final day1 = days.first as Map;
      expect((day1['fajr'] as int) - 1718413652000 <= 60000, isTrue);
      expect((day1['isha'] as int) - 1718476282000 <= 60000, isTrue);
      // Strictly increasing events and midnights; each day ordered.
      var prev = 0;
      for (final m in midnights) {
        expect((m as int) > prev, isTrue);
        prev = m;
      }
      for (final d in days) {
        final m = d as Map;
        final ordered = [
          m['fajr'],
          m['sunrise'],
          m['dhuhr'],
          m['asr'],
          m['maghrib'],
          m['isha'],
        ].cast<int>();
        for (var i = 1; i < ordered.length; i++) {
          expect(ordered[i] > ordered[i - 1], isTrue);
        }
      }
      // Cross-day continuity: day-2 fajr matches a direct calculation.
      final day2calc = PrayerScheduleCalculator.calculate(
        settings: _cairo,
        date: DateTime.utc(2024, 6, 16),
      )!;
      final day2 = days[1] as Map;
      expect(
        ((day2['fajr'] as int) -
                    day2calc.events[PrayerEventId.fajr]!.time
                        .millisecondsSinceEpoch)
                .abs() <=
            1000,
        isTrue,
      );
      // Contract v3: each day carries both Hijri labels, non-empty.
      for (final d in days) {
        final m = d as Map;
        expect((m['hb'] as String).isNotEmpty, isTrue);
        expect((m['ha'] as String).isNotEmpty, isTrue);
      }
      // Maghrib flips the label: ha is tomorrow's Hijri date.
      final day1hb = (days.first as Map)['hb'] as String;
      final day1ha = (days.first as Map)['ha'] as String;
      expect(day1hb, isNot(equals(day1ha)));
    });

    test('native payload is empty for invalid settings', () {
      final payload = buildNativeConfigMap(
        _cairo.copyWith(timezone: ''),
        now: DateTime.utc(2024, 6, 15, 12),
      );
      expect((payload['days'] as List), isEmpty);
      expect((payload['midnights'] as List), isEmpty);
    });
  });
}
