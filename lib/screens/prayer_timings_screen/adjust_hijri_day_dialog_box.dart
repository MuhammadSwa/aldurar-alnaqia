import 'package:aldurar_alnaqia/screens/prayer_timings_screen/hijri_adjust_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

/// Today's Hijri date adjusted by [offset] days, taking the Maghrib-based
/// Islamic day boundary into account. Pure: no prefs, no clock — callers pass
/// the cached Maghrib so this never triggers a calculation of its own.
HijriCalendar hijriDayWithOffset({
  required int offset,
  required DateTime now,
  required DateTime? maghrib,
}) {
  HijriCalendar.setLocal('ar');
  final adjustedDate = now.add(Duration(days: offset));
  if (maghrib != null && now.isAfter(maghrib)) {
    return HijriCalendar.fromDate(adjustedDate.add(const Duration(days: 1)));
  }
  return HijriCalendar.fromDate(adjustedDate);
}

class AdjustHijriDayDialogbox extends ConsumerWidget {
  const AdjustHijriDayDialogbox({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AlertDialog(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      content: HijriAdjustForm(showCancel: true),
    );
  }
}
