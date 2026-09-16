import 'package:aldurar_alnaqia/common/helpers/islamic_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2024, 6, 15, 12);
  final maghrib = DateTime(2024, 6, 15, 19, 30);

  group('islamicEffectiveDate', () {
    test('returns the same day before Maghrib', () {
      expect(
        islamicEffectiveDate(now: now, maghrib: maghrib),
        now,
      );
    });

    test('advances one day after Maghrib', () {
      final after = DateTime(2024, 6, 15, 20);
      expect(
        islamicEffectiveDate(now: after, maghrib: maghrib),
        after.add(const Duration(days: 1)),
      );
    });

    test('the exact Maghrib moment still belongs to the old day', () {
      // isAfter is strict: callers treat the boundary as pre-Maghrib.
      expect(islamicEffectiveDate(now: maghrib, maghrib: maghrib), maghrib);
    });

    test('null Maghrib never advances the day', () {
      final late = DateTime(2024, 6, 15, 23, 59);
      expect(islamicEffectiveDate(now: late, maghrib: null), late);
    });
  });

  group('islamicWeekday', () {
    test('matches the civil weekday before Maghrib', () {
      // 2024-06-15 is a Saturday.
      expect(islamicWeekday(now: now, maghrib: maghrib), DateTime.saturday);
    });

    test('flips to the next weekday after Maghrib', () {
      final after = DateTime(2024, 6, 15, 20);
      expect(islamicWeekday(now: after, maghrib: maghrib), DateTime.sunday);
    });

    test('wraps Sunday to Monday after Maghrib', () {
      final sundayNight = DateTime(2024, 6, 16, 21);
      final sundayMaghrib = DateTime(2024, 6, 16, 19, 30);
      expect(
        islamicWeekday(now: sundayNight, maghrib: sundayMaghrib),
        DateTime.monday,
      );
    });
  });
}
