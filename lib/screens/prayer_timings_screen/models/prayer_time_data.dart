// models/prayer_time_data.dart
class PrayerTimeData {
  final String name;
  final DateTime time;
  final bool isMainPrayer;

  const PrayerTimeData({
    required this.name,
    required this.time,
    this.isMainPrayer = true,
  });
}
