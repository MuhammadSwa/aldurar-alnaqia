import 'package:aldurar_alnaqia/screens/prayer_timings_screen/gregorian_date_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/hijri_date_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart'
    show prayerProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The day name comes from prayer controller state (flips at Maghrib);
// the dates below are Hijri | Gregorian.
class PrayerDateRow extends ConsumerWidget {
  const PrayerDateRow({super.key});

  static const Map<int, String> _arabicDayNames = {
    7: 'الأحد',
    1: 'الإثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
    6: 'السبت',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isInitialized =
        ref.watch(prayerProvider.select((s) => s.isInitialized));
    final weekday = ref.watch(prayerProvider.select((s) => s.islamicWeekday));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- Day name line (in place of the old location line) ----
            Text(
              !isInitialized ? '...' : (_arabicDayNames[weekday] ?? '...'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // ---- Dates row: Hijri | Gregorian ----
            Row(
              children: [
                const Expanded(
                  child: Center(child: HijriDateWidget()),
                ),
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: theme.dividerColor,
                ),
                const Expanded(
                  child: Center(child: GregorianDateWidget()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
