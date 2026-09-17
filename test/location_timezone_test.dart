import 'package:aldurar_alnaqia/screens/prayer_timings_screen/location_timezone.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';
import 'package:flutter_test/flutter_test.dart';

const cairo = City(
  nameEn: 'Cairo',
  nameAr: 'القاهرة',
  countryCode: 'EG',
  latitude: 30.0444,
  longitude: 31.2357,
  timeZone: 'Africa/Cairo',
);

const chicago = City(
  nameEn: 'Chicago',
  nameAr: null,
  countryCode: 'US',
  latitude: 41.8781,
  longitude: -87.6298,
  timeZone: 'America/Chicago',
);

const noTimezone = City(
  nameEn: 'Nowhere',
  nameAr: null,
  countryCode: 'XX',
  latitude: 0,
  longitude: 0,
  timeZone: null,
);

void main() {
  const cities = [cairo, chicago];

  group('LocationTimezone.resolve', () {
    test('uses a city picker selection’s exact GeoNames timezone', () {
      expect(
        LocationTimezone.resolve(
          latitude: cairo.latitude,
          longitude: cairo.longitude,
          cities: cities,
          selectedCity: chicago,
        ),
        'America/Chicago',
      );
    });

    test('uses the nearest GeoNames city for a GPS coordinate', () {
      expect(
        LocationTimezone.resolve(
          latitude: 30.05,
          longitude: 31.24,
          cities: cities,
        ),
        'Africa/Cairo',
      );
    });

    test('rejects invalid coordinates', () {
      expect(
        LocationTimezone.resolve(
          latitude: 91,
          longitude: 31.24,
          cities: cities,
        ),
        isNull,
      );
      expect(
        LocationTimezone.resolve(
          latitude: 30.05,
          longitude: 181,
          cities: cities,
        ),
        isNull,
      );
    });

    test('rejects non-finite coordinates', () {
      expect(
        LocationTimezone.resolve(
          latitude: double.nan,
          longitude: 31.24,
          cities: cities,
        ),
        isNull,
      );
      expect(
        LocationTimezone.resolve(
          latitude: 30.05,
          longitude: double.infinity,
          cities: cities,
        ),
        isNull,
      );
    });

    test('accepts boundary coordinates (poles and date line)', () {
      const northPole = City(
        nameEn: 'NorthPole',
        nameAr: null,
        countryCode: 'XX',
        latitude: 89.9,
        longitude: 0,
        timeZone: 'Arctic/Longyearbyen',
      );
      expect(
        LocationTimezone.resolve(
          latitude: 90,
          longitude: 0,
          cities: [northPole, cairo],
        ),
        'Arctic/Longyearbyen',
      );
      expect(
        LocationTimezone.resolve(
          latitude: -90,
          longitude: 180,
          cities: cities,
        ),
        isNotNull,
      );
    });

    test('returns null when there is nothing to match', () {
      expect(
        LocationTimezone.resolve(
          latitude: 30.05,
          longitude: 31.24,
          cities: const [],
        ),
        isNull,
      );
      expect(
        LocationTimezone.resolve(
          latitude: 30.05,
          longitude: 31.24,
          cities: const [noTimezone],
        ),
        isNull,
      );
    });

    test('skips cities without a timezone when finding nearest', () {
      // A timezone-less city exactly at the point must not shadow Cairo.
      const atPoint = City(
        nameEn: 'AtPoint',
        nameAr: null,
        countryCode: 'XX',
        latitude: 30.05,
        longitude: 31.24,
        timeZone: null,
      );
      expect(
        LocationTimezone.resolve(
          latitude: 30.05,
          longitude: 31.24,
          cities: const [atPoint, cairo],
        ),
        'Africa/Cairo',
      );
    });

    test('falls back to nearest when the selection has no timezone', () {
      expect(
        LocationTimezone.resolve(
          latitude: 30.05,
          longitude: 31.24,
          cities: cities,
          selectedCity: noTimezone,
        ),
        'Africa/Cairo',
      );
    });

    test('wraps longitude at the date line', () {
      // Nuku'alofa (+175.2) is ~2.4° from a point at -177.4 across the
      // date line; a naive delta would measure ~352° and pick Cairo.
      const nukualofa = City(
        nameEn: "Nuku'alofa",
        nameAr: null,
        countryCode: 'TO',
        latitude: -21.14,
        longitude: 175.2,
        timeZone: 'Pacific/Tongatapu',
      );
      expect(
        LocationTimezone.resolve(
          latitude: -21.0,
          longitude: -177.4,
          cities: [cairo, nukualofa],
        ),
        'Pacific/Tongatapu',
      );
    });

    test('a distance tie resolves to the first city (deterministic)', () {
      const north = City(
        nameEn: 'North',
        nameAr: null,
        countryCode: 'XX',
        latitude: 2,
        longitude: 0,
        timeZone: 'First/Zone',
      );
      const south = City(
        nameEn: 'South',
        nameAr: null,
        countryCode: 'XX',
        latitude: 0,
        longitude: 0,
        timeZone: 'Second/Zone',
      );
      expect(
        LocationTimezone.resolve(
          latitude: 1,
          longitude: 0,
          cities: const [north, south],
        ),
        'First/Zone',
      );
    });

    test('invalid coordinates win over a selected city', () {
      // Documents ordering: validation runs before the picker shortcut.
      expect(
        LocationTimezone.resolve(
          latitude: 91,
          longitude: 31.24,
          cities: cities,
          selectedCity: chicago,
        ),
        isNull,
      );
    });
  });

  group('LocationTimezone.nearestCity', () {
    // Equatorial fixtures so 1° of latitude ≈ 111.32 km exactly-ish and
    // longitude distortion stays out of the assertions.
    const origin = City(
      nameEn: 'Origin',
      nameAr: null,
      countryCode: 'XX',
      latitude: 0,
      longitude: 0,
      timeZone: 'Etc/UTC',
    );
    const far = City(
      nameEn: 'Far',
      nameAr: null,
      countryCode: 'XX',
      latitude: 10,
      longitude: 10,
      timeZone: 'Etc/UTC',
    );
    const cities2 = [origin, far];

    test('returns the city at the exact point', () {
      expect(
        LocationTimezone.nearestCity(
          latitude: 0,
          longitude: 0,
          cities: cities2,
        )?.nameEn,
        'Origin',
      );
    });

    test('returns cities within the default 50 km', () {
      // 0.4° of latitude ≈ 44.5 km < 50 km.
      expect(
        LocationTimezone.nearestCity(
          latitude: 0.4,
          longitude: 0,
          cities: cities2,
        )?.nameEn,
        'Origin',
      );
    });

    test('returns null beyond the default 50 km', () {
      // 0.5° of latitude ≈ 55.7 km > 50 km; Far is ~1500 km away.
      expect(
        LocationTimezone.nearestCity(
          latitude: 0.5,
          longitude: 0,
          cities: cities2,
        ),
        isNull,
      );
    });

    test('a custom maxKm widens the search', () {
      expect(
        LocationTimezone.nearestCity(
          latitude: 0.5,
          longitude: 0,
          cities: cities2,
          maxKm: 60,
        )?.nameEn,
        'Origin',
      );
    });

    test('picks the nearer city, not just the first', () {
      expect(
        LocationTimezone.nearestCity(
          latitude: 9.9,
          longitude: 9.9,
          cities: cities2,
          maxKm: 200,
        )?.nameEn,
        'Far',
      );
    });

    test('works for GPS points near real cities', () {
      expect(
        LocationTimezone.nearestCity(
          latitude: 30.05,
          longitude: 31.24,
          cities: cities,
        )?.nameEn,
        'Cairo',
      );
    });

    test('returns null in the middle of nowhere', () {
      expect(
        LocationTimezone.nearestCity(
          latitude: 0,
          longitude: -140,
          cities: cities,
        ),
        isNull,
      );
    });

    test('does not require a timezone (labels only)', () {
      // Unlike resolve, the label scan must not skip timezone-less towns.
      expect(
        LocationTimezone.nearestCity(
          latitude: 0,
          longitude: 0,
          cities: const [noTimezone],
        )?.nameEn,
        'Nowhere',
      );
    });

    test('rejects invalid coordinates and empty input', () {
      expect(
        LocationTimezone.nearestCity(
          latitude: 91,
          longitude: 0,
          cities: cities2,
        ),
        isNull,
      );
      expect(
        LocationTimezone.nearestCity(
          latitude: 0,
          longitude: 0,
          cities: const [],
        ),
        isNull,
      );
    });

    test('a distance tie resolves to the first city (deterministic)', () {
      const north = City(
        nameEn: 'North',
        nameAr: null,
        countryCode: 'XX',
        latitude: 1,
        longitude: 0,
        timeZone: 'First/Zone',
      );
      const south = City(
        nameEn: 'South',
        nameAr: null,
        countryCode: 'XX',
        latitude: -1,
        longitude: 0,
        timeZone: 'Second/Zone',
      );
      expect(
        LocationTimezone.nearestCity(
          latitude: 0,
          longitude: 0,
          cities: const [north, south],
          maxKm: 200,
        )?.nameEn,
        'North',
      );
    });
  });
}
