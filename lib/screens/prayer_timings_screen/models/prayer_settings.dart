// models/prayer_settings.dart
class PrayerSettings {
  final double latitude;
  final double longitude;
  final String calculationMethod;
  final String asrCalculation;

  const PrayerSettings({
    required this.latitude,
    required this.longitude,
    required this.calculationMethod,
    required this.asrCalculation,
  });

  bool get isValid =>
      latitude != 0.0 &&
      longitude != 0.0 &&
      calculationMethod.isNotEmpty &&
      asrCalculation.isNotEmpty;

  PrayerSettings copyWith({
    double? latitude,
    double? longitude,
    String? calculationMethod,
    String? asrCalculation,
  }) {
    return PrayerSettings(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      asrCalculation: asrCalculation ?? this.asrCalculation,
    );
  }
}
