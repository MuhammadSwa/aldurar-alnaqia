import 'package:hijri/hijri_calendar.dart';

/// Display label for a Hijri date with manual day [offset], taking the
/// Maghrib-based Islamic day boundary into account. Pure: no prefs, no clock.
///
/// Single source for Hijri rendering: the in-app widget and the native
/// notification payload both go through here, so they can never disagree.
String hijriLabel({
  required DateTime now,
  required DateTime? maghrib,
  required int offset,
}) {
  HijriCalendar.setLocal('ar');
  final adjusted = now.add(Duration(days: offset));
  final cal = (maghrib != null && now.isAfter(maghrib))
      ? HijriCalendar.fromDate(adjusted.add(const Duration(days: 1)))
      : HijriCalendar.fromDate(adjusted);
  // The `hijri` package names month 4 "ربيع الثاني" — display "ربيع الآخر".
  final month = cal.longMonthName.replaceAll('ربيع الثاني', 'ربيع الآخر');
  return '${cal.hDay} $month ${cal.hYear}';
}
