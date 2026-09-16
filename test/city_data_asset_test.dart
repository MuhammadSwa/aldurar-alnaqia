// Smoke test for the generated offline city database.
// Reads assets/data/cities.json straight from the repo (VM file access)
// and verifies it parses, searches, and contains sane data.
import 'dart:convert';
import 'dart:io';

import 'package:aldurar_alnaqia/screens/prayer_timings_screen/city_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('bundled cities.json parses and searches correctly', () {
    final file = File('assets/data/cities.json');
    expect(file.existsSync(), isTrue,
        reason: 'run `python3 tool/build_cities.py` to generate it',);

    final stopwatch = Stopwatch()..start();
    final directory = CityDirectory.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
    stopwatch.stop();

    expect(directory.cities.length, greaterThan(30000));

    // Spot-check well-known cities resolve with clean Arabic names.
    final cairo = directory.search('القاهرة');
    expect(cairo, isNotEmpty);
    expect(cairo.first.nameEn, 'Cairo');
    expect(cairo.first.displayName, 'القاهرة');
    expect(directory.cityLabel(cairo.first), 'القاهرة، مصر');

    expect(directory.search('Cairo').first.nameEn, 'Cairo');
    expect(directory.search('الاسكندريه').first.nameEn, 'Alexandria');
    expect(directory.search('مكة').first.nameEn, 'Makkah');

    // Regional overrides: no Israel entries; Jerusalem belongs to Palestine.
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

    // Every entry must have coordinates and a resolvable country.
    tz_data.initializeTimeZones();
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
      expect(() => tz.getLocation(timezone), returnsNormally,
          reason: '$timezone must be supported by package:timezone',);
    }

    // ignore: avoid_print
    print('cities: ${directory.cities.length}, '
        'parse: ${stopwatch.elapsedMilliseconds}ms');
  });
}
