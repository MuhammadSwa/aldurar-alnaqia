import 'package:intl/intl.dart' as intl;
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/prayer_schedule.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/common/widgets/inline_text.dart';
import 'package:timezone/timezone.dart' as tz;

/// Timetable card. Renders the cached [PrayerSchedule] from provider state —
/// no prayer calculation happens here (previously `getAllPrayerTimes()` plus
/// tomorrow's times were recomputed inside `build()`). Rebuilds only when the
/// schedule or the next-prayer highlight changes, never every second.
class PrayerTimingsCard extends ConsumerWidget {
  const PrayerTimingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. The day's schedule. Changes ~1x/day or on settings change.
    final schedule =
        ref.watch(prayerProvider.select((state) => state.schedule));
    if (schedule == null) {
      return _buildPlaceholderTable(context);
    }

    // 2. The next prayer name (changes at event boundaries only).
    final nextPrayerName =
        ref.watch(prayerProvider.select((s) => s.nextPrayerInfo.$2));

    final placeholderTime = tz.TZDateTime(tz.local, 1, 1, 1);
    final sunnah = schedule.sunnah;

    final prayers = [
      _PrayerTime('المغرب', schedule.events[PrayerEventId.maghrib]!.time),
      _PrayerTime('العشاء', schedule.events[PrayerEventId.isha]!.time),
      _PrayerTime('منتصف الليل', sunnah?.middleOfNight ?? placeholderTime,
          isSunnah: true,),
      _PrayerTime('الثلث الأخير', sunnah?.lastThirdOfNight ?? placeholderTime,
          isSunnah: true,),
      _PrayerTime('الفجر', schedule.events[PrayerEventId.fajr]!.time),
      _PrayerTime('الشروق', schedule.events[PrayerEventId.sunrise]!.time),
      _PrayerTime('الضحى', sunnah?.duha ?? placeholderTime, isSunnah: true),
      _PrayerTime('الظهر', schedule.events[PrayerEventId.dhuhr]!.time),
      _PrayerTime('العصر', schedule.events[PrayerEventId.asr]!.time),
    ];

    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.2),),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
          },
          children: prayers.map((prayer) {
            final isNextPrayer = prayer.name == nextPrayerName;
            return _buildTableRow(context, prayer, isNextPrayer);
          }).toList(),
        ),
      ),
    );
  }

  // --- REFACTORED: This is now a "dumb" builder method ---
  // It receives all the data it needs and contains NO reactive code.
  TableRow _buildTableRow(
      BuildContext context, _PrayerTime prayer, bool isNextPrayer,) {
    final Color? rowColor = isNextPrayer
        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
        : null;
    final border = BorderSide(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        width: 0.5,);

    return TableRow(
      children: [
        // Prayer Name Cell
        Container(
          decoration:
              BoxDecoration(color: rowColor, border: Border(bottom: border)),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: InlineTextWidget(
            prayer.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: prayer.isSunnah ? FontWeight.w500 : FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        // Prayer Time Cell
        Container(
          decoration:
              BoxDecoration(color: rowColor, border: Border(bottom: border)),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: InlineTextWidget(
            _formatTime(prayer.time),
            style: const TextStyle(
                fontSize: 16,
                fontFamily: 'monospace',
                fontWeight: FontWeight.normal,),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // Helper method to build the placeholder table to avoid code duplication
  Widget _buildPlaceholderTable(BuildContext context) {
    final placeholderTime = tz.TZDateTime(tz.local, 1, 1, 1);
    final prayers = [
      _PrayerTime('المغرب', placeholderTime),
      _PrayerTime('العشاء', placeholderTime),
      _PrayerTime('منتصف الليل', placeholderTime, isSunnah: true),
      _PrayerTime('الثلث الأخير', placeholderTime, isSunnah: true),
      _PrayerTime('الفجر', placeholderTime),
      _PrayerTime('الشروق', placeholderTime),
      _PrayerTime('الضحى', placeholderTime, isSunnah: true),
      _PrayerTime('الظهر', placeholderTime),
      _PrayerTime('العصر', placeholderTime),
    ];

    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
          children: prayers
              .map((prayer) => _buildTableRow(context, prayer, false))
              .toList(),
        ),
      ),
    );
  }

  String _formatTime(tz.TZDateTime time) {
    if (time.year <= 1) {
      return '--:--';
    }
    final period = (time.hour >= 12) ? 'م' : 'ص';
    final format = intl.DateFormat('hh:mm', 'en_US');
    return '${format.format(time)} $period';
  }
}

class _PrayerTime {
  final String name;
  final tz.TZDateTime time;
  final bool isSunnah;

  const _PrayerTime(this.name, this.time, {this.isSunnah = false});
}
