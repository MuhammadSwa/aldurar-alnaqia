// models/next_prayer_info.dart
class NextPrayerInfo {
  final String name;
  final Duration timeRemaining;
  final DateTime nextPrayerTime;

  const NextPrayerInfo({
    required this.name,
    required this.timeRemaining,
    required this.nextPrayerTime,
  });
}
