import 'package:aldurar_alnaqia/common/helpers/islamic_date.dart'
    as islamic_date;
import 'package:aldurar_alnaqia/models/consts/salawat_yousria_collection.dart';
import 'package:aldurar_alnaqia/prayer/prayer_repository.dart'
    show todayPrayerSchedule;
import 'package:aldurar_alnaqia/services/shared_prefs.dart';

/// Which part of the 6-day Yousria cycle is read today.
class YousriaDayInfo {
  const YousriaDayInfo({
    required this.dayNumber,
    required this.zikrId,
    required this.title,
    required this.startDate,
  });

  /// 1..6
  final int dayNumber;

  /// Stable zikr id of today's part.
  final String zikrId;

  /// Display title of today's part.
  final String title;
  final DateTime startDate;
}

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// The civil date of the current *Islamic* day: between Maghrib and
/// midnight the Islamic day has already advanced to tomorrow.
DateTime islamicEffectiveDate() {
  final maghrib = todayPrayerSchedule()?.maghrib;
  return islamic_date.islamicEffectiveDate(
    now: DateTime.now(),
    maghrib: maghrib,
  );
}

/// Computes today's Yousria part (1..6) from the stored beginning day.
/// Both dates are truncated to midnight so hours never shift the cycle,
/// and the modulo is normalized so old beginnings wrap correctly.
YousriaDayInfo getYousriaDayInfo() {
  final startingDay = _midnight(SharedPreferencesService.getYousriaBeginning());
  final effectiveDay = _midnight(islamicEffectiveDate());
  final diff = effectiveDay.difference(startingDay).inDays;
  final dayNumber = (diff % 6 + 6) % 6 + 1;
  final zikr = yousriaDayZikr(dayNumber);
  return YousriaDayInfo(
    dayNumber: dayNumber,
    zikrId: zikr.id,
    title: zikr.title,
    startDate: startingDay,
  );
}

List<String> getYousriaForToday() {
  return <String>[getYousriaDayInfo().zikrId];
}
