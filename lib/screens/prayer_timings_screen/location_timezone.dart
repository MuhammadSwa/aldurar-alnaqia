import 'dart:math' as math;

import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';

/// Resolves a selected coordinate to the GeoNames timezone of its nearest
/// indexed city. City-picker selections use their exact GeoNames timezone;
/// GPS selections use the same offline data without consulting the device.
abstract final class LocationTimezone {
  static String? resolve({
    required double latitude,
    required double longitude,
    required Iterable<City> cities,
    City? selectedCity,
  }) {
    if (!_isValidCoordinate(latitude, longitude)) return null;

    final selectedTimezone = selectedCity?.timeZone;
    if (selectedTimezone != null && selectedTimezone.isNotEmpty) {
      return selectedTimezone;
    }

    City? nearest;
    var nearestDistance = double.infinity;
    for (final city in cities) {
      final timezone = city.timeZone;
      if (timezone == null || timezone.isEmpty) continue;
      final distance = _squaredDistance(latitude, longitude, city);
      if (distance < nearestDistance) {
        nearest = city;
        nearestDistance = distance;
      }
    }
    return nearest?.timeZone;
  }

  static bool _isValidCoordinate(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  /// Equirectangular distance with longitude wrapped at the date line.
  static double _squaredDistance(double latitude, double longitude, City city) {
    final meanLatitude = (latitude + city.latitude) * math.pi / 360;
    final latitudeDelta = latitude - city.latitude;
    var longitudeDelta = (longitude - city.longitude).abs();
    if (longitudeDelta > 180) longitudeDelta = 360 - longitudeDelta;
    final eastWest = longitudeDelta * math.cos(meanLatitude);
    return latitudeDelta * latitudeDelta + eastWest * eastWest;
  }
}
