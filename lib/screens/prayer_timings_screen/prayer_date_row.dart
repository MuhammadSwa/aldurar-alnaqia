import 'package:aldurar_alnaqia/prayer/prayer_providers.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/gregorian_date_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/hijri_date_widget.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Shared separator style for the prayer header: the Hijri|Gregorian divider
/// and the dates/countdown divider use the same color and weight.
Color prayerSeparatorColor(BuildContext context) =>
    Theme.of(context).colorScheme.outline.withValues(alpha: 0.45);

/// Day name (flips at Maghrib) + Hijri | Gregorian dates.
///
/// Pure derivation: weekday, Hijri label, and civil date all come from the
/// watched [prayerViewProvider] plus wall-clock time at build. Rebuilds on
/// nudge/settings changes; keeps no timers of its own.
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
    final view = ref.watch(prayerViewProvider);
    final offset = ref.watch(hijriOffsetProvider);

    final now = view?.today ?? DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- Day name line (in place of the old location line) ----
          Text(
              view == null ? '...' : (_arabicDayNames[view.weekday] ?? '...'),
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
                Expanded(
                  child: Center(
                    child: HijriDateWidget(
                      now: now,
                      maghrib: view?.schedule.maghrib,
                      offset: offset,
                    ),
                  ),
                ),
                Container(
                  width: 1.5,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: prayerSeparatorColor(context),
                ),
                Expanded(
                  child: Center(child: GregorianDateWidget(today: now)),
                ),
              ],
            ),
          ],
        ),
      );
  }
}
