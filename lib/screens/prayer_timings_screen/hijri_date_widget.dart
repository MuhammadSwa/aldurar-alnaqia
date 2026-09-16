// lib/widgets/hijri_date_widget.dart

import 'package:aldurar_alnaqia/screens/prayer_timings_screen/adjust_hijri_day_dialog_box.dart'
    show hijriDayWithOffset;
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

/// Hijri date label. Pure renderer: the Maghrib boundary is owned by
/// `PrayerTimingsNotifier` (which recalculates at Maghrib), so this widget
/// keeps no timer and performs no solar calculation — it reads the cached
/// Maghrib from provider state plus the manual offset, and rebuilds only
/// when one of those changes.
class HijriDateWidget extends ConsumerWidget {
  const HijriDateWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offset = ref.watch(hijriOffsetProvider);
    final maghrib =
        ref.watch(prayerProvider.select((s) => s.schedule?.maghrib));

    final hijriDate = hijriDayWithOffset(
      offset: offset,
      now: tz.TZDateTime.now(tz.local),
      maghrib: maghrib,
    );
    // The `hijri` package names month 4 as "ربيع الثاني" — display it as
    // "ربيع الآخر" instead.
    final monthName =
        hijriDate.longMonthName.replaceAll('ربيع الثاني', 'ربيع الآخر');
    return Text(
      '${hijriDate.hDay} $monthName ${hijriDate.hYear}',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}
