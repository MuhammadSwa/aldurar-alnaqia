// Smoke tests for the generated offline city database.
// Reads assets/data/cities.json straight from the repo (VM file access)
// and verifies it parses, searches, and contains sane data.
//
// The fast tests below run on every `flutter test`. The exhaustive per-city
// audit is tagged `nightly` (slow: ~34k entries) — run it with:
//   flutter test --tags nightly test/city_data_asset_test.dart
// or exclude it explicitly with `flutter test --exclude-tags nightly`.
import 'dart:convert';
import 'dart:io';

import 'package:aldurar_alnaqia/screens/prayer_timings_screen/city_directory.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late CityDirectory directory;
  late int parseMs;

  setUpAll(() {
    final file = File('assets/data/cities.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'run `python3 tool/build_cities.py` to generate it',
    );

    final stopwatch = Stopwatch()..start();
    directory = CityDirectory.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
    stopwatch.stop();
    parseMs = stopwatch.elapsedMilliseconds;

    tz_data.initializeTimeZones();
  });

  group('bundled cities.json', () {
    test('parses a full database quickly', () {
      expect(directory.cities.length, greaterThan(30000));
      expect(parseMs, lessThan(10000),
          reason: 'parse took ${parseMs}ms; check for regressions',);
    });

    test('spot-checks well-known cities with clean Arabic names', () {
      final cairo = directory.search('القاهرة');
      expect(cairo, isNotEmpty);
      expect(cairo.first.nameEn, 'Cairo');
      expect(cairo.first.displayName, 'القاهرة');
      expect(directory.cityLabel(cairo.first), 'القاهرة، مصر');

      expect(directory.search('Cairo').first.nameEn, 'Cairo');
      expect(directory.search('الاسكندريه').first.nameEn, 'Alexandria');
      expect(directory.search('مكة').first.nameEn, 'Makkah');
    });

    test('regional overrides: no Israel entries; Jerusalem is Palestine', () {
      expect(directory.countries.containsKey('IL'), isFalse);
      expect(directory.countries['PS']?.displayName, 'فلسطين');
      expect(
        directory.cities.where((c) => c.countryCode == 'IL'),
        isEmpty,
      );
      final jerusalem = directory.search('Jerusalem');
      expect(jerusalem, isNotEmpty);
      expect(jerusalem.first.nameEn, 'Jerusalem');
      expect(jerusalem.first.displayName, 'القدس الشريف');
      expect(jerusalem.first.countryCode, 'PS');
      expect(directory.cityLabel(jerusalem.first), 'القدس الشريف، فلسطين');
    });

    test('a sample of timezones resolve via package:timezone', () {
      // Fast proxy for the full audit: every distinct timezone among the
      // first 500 cities must be known to package:timezone.
      final timezones =
          directory.cities.take(500).map((c) => c.timeZone).toSet();
      expect(timezones, isNotEmpty);
      expect(timezones, everyElement(isNotNull));
      for (final timezone in timezones) {
        expect(
          () => tz.getLocation(timezone!),
          returnsNormally,
          reason: '$timezone must be supported by package:timezone',
        );
      }
    });

    test(
      'every entry has coordinates, a country, and a known timezone',
      tags: 'nightly',
      timeout: const Timeout(Duration(minutes: 5)),
      () {
        final timezones = <String>{};
        for (final city in directory.cities) {
          expect(city.nameEn, isNotEmpty);
          expect(city.latitude, inInclusiveRange(-90.0, 90.0));
          expect(city.longitude, inInclusiveRange(-180.0, 180.0));
          expect(city.timeZone, isNotNull);
          expect(city.timeZone, isNotEmpty);
          timezones.add(city.timeZone!);
        }
        for (final timezone in timezones) {
          expect(
            () => tz.getLocation(timezone),
            returnsNormally,
            reason: '$timezone must be supported by package:timezone',
          );
        }

        // Test summary for local debugging; not user-facing output.
        // ignore: avoid_print
        print('cities: ${directory.cities.length}, parse: ${parseMs}ms');
      },
    );
  });

  group('City model', () {
    test('displayName falls back to English when Arabic is missing', () {
      const city = City(
        nameEn: 'Springfield',
        nameAr: null,
        countryCode: 'US',
        latitude: 39.78,
        longitude: -89.65,
        timeZone: 'America/Chicago',
      );
      expect(city.displayName, 'Springfield');
    });
  });
}
