import 'package:aldurar_alnaqia/screens/prayer_timings_screen/gregorian_date_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/hijri_date_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_settings_dialog.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart'
    show prayerProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The location label comes from prayer controller state 
// (persisted at save time — no directory load needed to render);
// when unconfigured, the line invites the user to set up,
// and tapping it opens the settings dialog.
class PrayerDateRow extends ConsumerWidget {
  const PrayerDateRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final label = ref.watch(prayerProvider.select((s) => s.cityLabel));
    final isUnset = label.isEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- Location line ----
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openSettings(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isUnset
                          ? Icons.location_off_outlined
                          : Icons.location_on_outlined,
                      size: 16,
                      color:
                          isUnset ? theme.hintColor : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        isUnset ? 'اضغط لتحديد الموقع' : label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isUnset
                              ? theme.hintColor
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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

  void _openSettings(BuildContext context) {
    showDialog(context: context, builder: (_) => const PrayerSettingsDialog());
  }
}
