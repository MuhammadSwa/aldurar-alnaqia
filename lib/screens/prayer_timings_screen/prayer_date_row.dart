import 'package:aldurar_alnaqia/screens/prayer_timings_screen/gregorian_date_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/hijri_date_widget.dart';
import 'package:flutter/material.dart';

class PrayerDateRow extends StatelessWidget {
  const PrayerDateRow({super.key, this.location});

  /// Wire later: pass the resolved user location here (or convert this to a
  /// ConsumerWidget and `ref.watch(locationProvider)`).
  final String? location;

  // TODO(location): replace with the real user location once geolocation lands.
  static const String _placeholderLocation = 'القاهرة، مصر';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayLocation = location ?? _placeholderLocation;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- Location line (placeholder) ----
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    displayLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
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
