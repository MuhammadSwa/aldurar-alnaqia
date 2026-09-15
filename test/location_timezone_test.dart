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

void main() {
  const cities = [cairo, chicago];

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
  });
}
