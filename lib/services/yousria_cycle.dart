import 'package:aldurar_alnaqia/common/helpers/islamic_date.dart'
    as islamic_date;
import 'package:aldurar_alnaqia/models/consts/salawat_yousria_collection.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_calculator.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';

/// Which part of the 6-day Yousria cycle is read today.
class YousriaDayInfo {
  const YousriaDayInfo({
    required this.dayNumber,
    required this.title,
    required this.startDate,
  });

  /// 1..6
  final int dayNumber;
  final String title;
  final DateTime startDate;
}

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// The civil date of the current *Islamic* day: between Maghrib and
/// midnight the Islamic day has already advanced to tomorrow.
DateTime islamicEffectiveDate() {
  final now = DateTime.now();
  final maghrib = PrayerTimeings.getPrayersTimings()?.maghrib;
  return islamic_date.islamicEffectiveDate(now: now, maghrib: maghrib);
}

/// Computes today's Yousria part (1..6) from the stored beginning day.
/// Both dates are truncated to midnight so hours never shift the cycle,
/// and the modulo is normalized so old beginnings wrap correctly.
YousriaDayInfo getYousriaDayInfo() {
  final startingDay = _midnight(SharedPreferencesService.getYousriaBeginning());
  final effectiveDay = _midnight(islamicEffectiveDate());
  final diff = effectiveDay.difference(startingDay).inDays;
  final dayNumber = (diff % 6 + 6) % 6 + 1;
  // salawatYousriaCollection: 0 intro, 1 asmaa, 2..7 day1..day6.
  final title = salawatYousriaCollection[dayNumber + 1].title;
  return YousriaDayInfo(
    dayNumber: dayNumber,
    title: title,
    startDate: startingDay,
  );
}

List<String> getYousriaForToday() {
  return <String>[getYousriaDayInfo().title];
}
