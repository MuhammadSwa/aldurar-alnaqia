// Timeline progress tests for the next-prayer countdown.
//
// The bar measures elapsed time on the continuous prayer timeline
// (prev … now … next), not within one civil-day bucket. Between midnight
// and Fajr the previous event lives in yesterday's bucket, so the bar must
// stay visible there instead of resolving to null.

import 'package:aldurar_alnaqia/prayer/prayer_repository.dart';
import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const _settings = PrayerSettings(
  latitude: 30.0444,
  longitude: 31.2357,
  timezone: 'Africa/Cairo',
  method: PrayerMethods.egyptian,
  madhab: PrayerMadhabs.shafi,
  highLatitudeRule: PrayerHighLatitudeRules.middleOfNight,
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  tz.TZDateTime at(int month, int day, int hour, [int minute = 0]) {
    final loc = tz.getLocation('Africa/Cairo');
    return tz.TZDateTime(loc, 2024, month, day, hour, minute);
  }

  test('before Fajr the previous event is yesterday Isha', () {
    final repo = PrayerRepository();
    final now = at(6, 15, 0, 30);

    final prev = repo.prevAt(_settings, now)!;
    final next = repo.nextAt(_settings, now)!;

    expect(next.id, PrayerEventId.fajr);
    expect(prev.id, PrayerEventId.isha);
    expect(prev.time.isBefore(now), isTrue);
    expect(now.isBefore(next.time), isTrue);
    // Yesterday's bucket: Isha belongs to the previous civil day.
    expect(prev.time.day, 14);
    expect(next.time.day, 15);
    expect(next.time.difference(now).isNegative, isFalse);
  });

  test('before Fajr the bar has a well-formed 0–1 progress', () {
    final repo = PrayerRepository();
    final progress = repo.progressAt(_settings, at(6, 15, 0, 30))!;
    expect(progress, inInclusiveRange(0.0, 1.0));
  });

  test('month boundary: June 1 overnight anchors on May 31 Isha', () {
    final repo = PrayerRepository();
    final now = at(6, 1, 0, 30);

    final prev = repo.prevAt(_settings, now)!;
    final next = repo.nextAt(_settings, now)!;

    expect(next.id, PrayerEventId.fajr);
    expect(prev.id, PrayerEventId.isha);
    // Field-based day-1 math would miss this; Duration arithmetic must not.
    expect(prev.time.month, 5);
    expect(prev.time.day, 31);
    expect(repo.progressAt(_settings, now), isNotNull);
  });

  test('daytime still uses the same-day previous event', () {
    final repo = PrayerRepository();
    // Mid-morning Cairo: after sunrise, before Dhuhr.
    final now = at(6, 15, 9);

    final prev = repo.prevAt(_settings, now)!;
    expect(prev.id, PrayerEventId.sunrise);
    expect(prev.time.day, 15);
  });

  test('after Isha the interval runs to tomorrow Fajr', () {
    final repo = PrayerRepository();
    final now = at(6, 15, 22, 30);

    final prev = repo.prevAt(_settings, now)!;
    final next = repo.nextAt(_settings, now)!;
    expect(prev.id, PrayerEventId.isha);
    expect(next.id, PrayerEventId.fajr);
    expect(next.time.isAfter(now), isTrue);
    expect(repo.progressAt(_settings, now), isNotNull);
  });
}
