import 'package:aldurar_alnaqia/screens/prayer_timings_screen/city_directory.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fixture: no asset loading, so this runs as a pure unit test.
CityDirectory buildTestDirectory() {
  return CityDirectory.fromJson({
    'countries': {
      'EG': {'ar': 'مصر', 'en': 'Egypt'},
      'SA': {'ar': 'السعودية', 'en': 'Saudi Arabia'},
      'US': {'en': 'United States'},
    },
    'cities': [
      {
        'en': 'Cairo',
        'ar': 'القاهرة',
        'country': 'EG',
        'lat': 30.063,
        'lng': 31.25,
        'tz': 'Africa/Cairo',
      },
      {
        'en': 'Alexandria',
        'ar': 'الإسكندرية',
        'country': 'EG',
        'lat': 31.202,
        'lng': 29.916,
        'tz': 'Africa/Cairo',
      },
      {
        'en': 'Madinat an Nasr',
        'ar': 'مدينة نصر',
        'country': 'EG',
        'lat': 30.067,
        'lng': 31.3,
        'tz': 'Africa/Cairo',
      },
      {
        'en': 'Springfield',
        'country': 'US',
        'lat': 39.781,
        'lng': -89.65,
        'tz': 'America/Chicago',
      },
    ],
  });
}

void main() {
  late CityDirectory directory;

  setUp(() => directory = buildTestDirectory());

  group('normalize', () {
    test('unifies hamza/ta-marbuta/ya spellings', () {
      expect(CityDirectory.normalize('القاهرة'),
          CityDirectory.normalize('القاهره'));
      expect(CityDirectory.normalize('الإسكندرية'),
          CityDirectory.normalize('الاسكندريه'));
    });

    test('strips diacritics and lowercases latin', () {
      expect(CityDirectory.normalize('مَكَّة'), 'مكه');
      expect(CityDirectory.normalize('  CAIRO '), 'cairo');
    });
  });

  group('search', () {
    test('empty query returns no results', () {
      expect(directory.search(''), isEmpty);
      expect(directory.search('   '), isEmpty);
    });

    test('finds Arabic names without the ال prefix', () {
      final results = directory.search('قاهرة');
      expect(results, isNotEmpty);
      expect(results.first.nameEn, 'Cairo');
    });

    test('tolerates ه/ة and ى/ي spelling variants', () {
      expect(directory.search('القاهره').first.nameEn, 'Cairo');
      expect(directory.search('الاسكندريه').first.nameEn, 'Alexandria');
    });

    test('finds English names case-insensitively', () {
      expect(directory.search('cairo').first.nameEn, 'Cairo');
      expect(directory.search('CAIRO').first.nameEn, 'Cairo');
    });

    test('finds cities that only have an English name', () {
      final results = directory.search('springfield');
      expect(results, hasLength(1));
      expect(results.first.displayName, 'Springfield');
    });

    test('exact match outranks substring match', () {
      // 'سكندر' is a substring of Alexandria but 'الاسكندرية' is also a
      // prefix-ish hit; exact full-name query must win.
      final results = directory.search('الإسكندرية');
      expect(results.first.nameEn, 'Alexandria');
    });

    test('respects the limit', () {
      expect(directory.search('ا', limit: 2), hasLength(2));
    });

    test('country name lists all cities of that country', () {
      final byArabic = directory.search('مصر');
      expect(byArabic.map((c) => c.nameEn),
          containsAll(['Cairo', 'Alexandria', 'Madinat an Nasr']));
      expect(byArabic.map((c) => c.nameEn), isNot(contains('Springfield')));

      final byEnglish = directory.search('Egypt');
      expect(byEnglish.map((c) => c.nameEn),
          containsAll(['Cairo', 'Alexandria', 'Madinat an Nasr']));

      expect(directory.search('United States').map((c) => c.nameEn),
          ['Springfield']);
    });

    test('country prefix matches too', () {
      final results = directory.search('مص');
      expect(results.map((c) => c.nameEn),
          containsAll(['Cairo', 'Alexandria', 'Madinat an Nasr']));
    });

    test('city-name match outranks country-name match', () {
      // 'القاهرة' is a city exact hit; it must stay first even though
      // other EG cities match via the country name.
      expect(directory.search('القاهرة').first.nameEn, 'Cairo');
    });

    test('countMatches includes country-name matches', () {
      expect(directory.countMatches('مصر'), 3);
    });
  });

  group('labels', () {
    test('countryLabel prefers Arabic, falls back to English then code', () {
      expect(directory.countryLabel('EG'), 'مصر');
      expect(directory.countryLabel('US'), 'United States');
      expect(directory.countryLabel('XX'), 'XX');
    });

    test('cityLabel combines city and country', () {
      final cairo = directory.search('Cairo').first;
      expect(directory.cityLabel(cairo), 'القاهرة، مصر');
    });
  });
}
