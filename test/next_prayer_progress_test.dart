// Overnight progress-interval tests for the next-prayer countdown.
//
// Proves: between midnight and Fajr the bar's interval starts at
// yesterday's Isha (bar stays visible) instead of resolving to null,
// and daytime behavior is unchanged.

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:aldurar_alnaqia/prayer/prayer_repository.dart';
import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/next_prayer_countdown.dart';

const _settings = PrayerSettings(
  latitude: 30.0444,
  longitude: 31.2357,
  timezone: 'Africa/Cairo',
  method: PrayerMethods.egyptian,
  madhab: PrayerMadhabs.shafi,
  highLatitudeRule: PrayerHighLatitudeRules.middleOfNight,
);

void main() {
  setUpAll(() => tzdata.initializeTimeZones());

  PrayerSchedule day(PrayerRepository repo, int day) {
    final loc = tz.getLocation('Africa/Cairo');
    return repo.scheduleFor(
      _settings,
      tz.TZDateTime(loc, 2024, 6, day, 12),
    )!;
  }

  test('before Fajr the interval starts at yesterday Isha', () {
    final repo = PrayerRepository();
    final today = day(repo, 15);
    final yesterday = day(repo, 14);
    final loc = tz.getLocation('Africa/Cairo');
    final now = tz.TZDateTime(loc, 2024, 6, 15, 0, 30);

    final start = progressIntervalStart(
      schedule: today,
      yesterdaySchedule: yesterday,
      now: now,
    );

    expect(
      start,
      yesterday.events[PrayerEventId.isha]!.time,
      reason: 'midnight→Fajr must anchor on yesterday Isha, not null',
    );

    // The full interval is well-formed: Isha < now < Fajr.
    final next = repo.nextAt(_settings, now)!;
    expect(next.id, PrayerEventId.fajr);
    expect(start!.isBefore(now), isTrue);
    expect(now.isBefore(next.time), isTrue);
    // Countdown itself is positive in the overnight window.
    expect(next.time.difference(now).isNegative, isFalse);
  });

  test('before Fajr without yesterday schedule stays null', () {
    final repo = PrayerRepository();
    final today = day(repo, 15);
    final loc = tz.getLocation('Africa/Cairo');
    expect(
      progressIntervalStart(
        schedule: today,
        yesterdaySchedule: null,
        now: tz.TZDateTime(loc, 2024, 6, 15, 0, 30),
      ),
      isNull,
    );
  });

  test('daytime still uses the same-day previous event', () {
    final repo = PrayerRepository();
    final today = day(repo, 15);
    final loc = tz.getLocation('Africa/Cairo');
    // Mid-morning Cairo: after sunrise, before Dhuhr.
    final now = tz.TZDateTime(loc, 2024, 6, 15, 9);
    expect(
      progressIntervalStart(
        schedule: today,
        yesterdaySchedule: day(repo, 14),
        now: now,
      ),
      today.events[PrayerEventId.sunrise]!.time,
    );
  });

  test('after Isha the interval starts at today Isha', () {
    final repo = PrayerRepository();
    final today = day(repo, 15);
    final loc = tz.getLocation('Africa/Cairo');
    final now = tz.TZDateTime(loc, 2024, 6, 15, 22, 30);
    expect(
      progressIntervalStart(
        schedule: today,
        yesterdaySchedule: day(repo, 14),
        now: now,
      ),
      today.events[PrayerEventId.isha]!.time,
    );
    // Next is tomorrow's Fajr; interval stays well-formed overnight.
    final next = repo.nextAt(_settings, now)!;
    expect(next.id, PrayerEventId.fajr);
    expect(next.time.isAfter(now), isTrue);
  });
}
