import 'package:intl/intl.dart' as intl;
import 'package:aldurar_alnaqia/prayer/prayer_providers.dart';
import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/common/widgets/inline_text.dart';

/// Timetable card. Renders the cached daily schedule; the highlighted row is
/// derived at build time by matching the prayer's instant against the next
/// event (not by name), so after Isha — when next is *tomorrow's* Fajr — no
/// row is wrongly highlighted. Rebuilds only on nudge/settings changes.
class PrayerTimingsCard extends ConsumerWidget {
  const PrayerTimingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Null while unconfigured: setup prompt lives on the timings screen.
    final view = ref.watch(prayerViewProvider);
    if (view == null) {
      return _buildPlaceholderTable(context);
    }
    final schedule = view.schedule;
    final nextMs = view.next.time.millisecondsSinceEpoch;
    final sunnah = schedule.sunnah;

    // Main box: fard prayers + sunrise. Sunnah times live in their own
    // box below, mirroring the same listing style.
    final fardPrayers = [
      _PrayerTime('المغرب', schedule.events[PrayerEventId.maghrib]!.time),
      _PrayerTime('العشاء', schedule.events[PrayerEventId.isha]!.time),
      _PrayerTime('الفجر', schedule.events[PrayerEventId.fajr]!.time),
      _PrayerTime('الشروق', schedule.events[PrayerEventId.sunrise]!.time),
      _PrayerTime('الظهر', schedule.events[PrayerEventId.dhuhr]!.time),
      _PrayerTime('العصر', schedule.events[PrayerEventId.asr]!.time),
    ];

    final sunnahPrayers = [
      _PrayerTime('منتصف الليل', sunnah?.middleOfNight, isSunnah: true),
      _PrayerTime('الثلث الأخير', sunnah?.lastThirdOfNight, isSunnah: true),
      _PrayerTime('الضحى', sunnah?.duha, isSunnah: true),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCard(context, fardPrayers, nextMs),
        const SizedBox(height: 8),
        _buildCard(context, sunnahPrayers, nextMs),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    List<_PrayerTime> prayers,
    int nextMs,
  ) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
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
            final isNextPrayer = prayer.time?.millisecondsSinceEpoch == nextMs;
            return _buildTableRow(context, prayer, isNextPrayer);
          }).toList(),
        ),
      ),
    );
  }

  // --- REFACTORED: This is now a "dumb" builder method ---
  // It receives all the data it needs and contains NO reactive code.
  TableRow _buildTableRow(
    BuildContext context,
    _PrayerTime prayer,
    bool isNextPrayer,
  ) {
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
    const fardPrayers = [
      _PrayerTime('المغرب', null),
      _PrayerTime('العشاء', null),
      _PrayerTime('الفجر', null),
      _PrayerTime('الشروق', null),
      _PrayerTime('الظهر', null),
      _PrayerTime('العصر', null),
    ];
    const sunnahPrayers = [
      _PrayerTime('منتصف الليل', null, isSunnah: true),
      _PrayerTime('الثلث الأخير', null, isSunnah: true),
      _PrayerTime('الضحى', null, isSunnah: true),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          elevation: 4,
          margin: EdgeInsets.zero,
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
              children: fardPrayers
                  .map((prayer) => _buildTableRow(context, prayer, false))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 4,
          margin: EdgeInsets.zero,
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
              children: sunnahPrayers
                  .map((prayer) => _buildTableRow(context, prayer, false))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) {
      return '--:--';
    }
    final period = (time.hour >= 12) ? 'م' : 'ص';
    final format = intl.DateFormat('hh:mm', 'en_US');
    return '${format.format(time)} $period';
  }
}

class _PrayerTime {
  final String name;
  final DateTime? time;
  final bool isSunnah;

  const _PrayerTime(this.name, this.time, {this.isSunnah = false});
}
