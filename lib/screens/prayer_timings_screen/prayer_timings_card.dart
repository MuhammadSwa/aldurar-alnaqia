import 'package:intl/intl.dart' as intl;
import 'package:aldurar_alnaqia/prayer/prayer_providers.dart';
import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:aldurar_alnaqia/common/widgets/inline_text.dart';

/// Timetable card. Renders the cached daily schedule; the highlighted row is
/// derived at build time by matching the prayer's instant against the next
/// event (not by name), so after Isha — when next is *tomorrow's* Fajr — no
/// row is wrongly highlighted. Rebuilds only on nudge/settings changes.
///
/// Each fard row shows a time-of-day tinted medallion; the next prayer's row
/// carries a progress bar measuring prev → next elapsed time.
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
      _PrayerTime('المغرب', schedule.events[PrayerEventId.maghrib]!.time,
          id: PrayerEventId.maghrib, icon: LucideIcons.sunset,),
      _PrayerTime('العشاء', schedule.events[PrayerEventId.isha]!.time,
          id: PrayerEventId.isha, icon: LucideIcons.moon,),
      _PrayerTime('الفجر', schedule.events[PrayerEventId.fajr]!.time,
          id: PrayerEventId.fajr, icon: LucideIcons.sunMoon,),
      _PrayerTime('الشروق', schedule.events[PrayerEventId.sunrise]!.time,
          id: PrayerEventId.sunrise, icon: LucideIcons.sunrise,),
      _PrayerTime('الظهر', schedule.events[PrayerEventId.dhuhr]!.time,
          id: PrayerEventId.dhuhr, icon: LucideIcons.sun,),
      _PrayerTime('العصر', schedule.events[PrayerEventId.asr]!.time,
          id: PrayerEventId.asr, icon: LucideIcons.cloudSun,),
    ];

    final sunnahPrayers = [
      _PrayerTime('منتصف الليل', sunnah?.middleOfNight, isSunnah: true),
      _PrayerTime('الثلث الأخير', sunnah?.lastThirdOfNight, isSunnah: true),
      _PrayerTime('الضحى', sunnah?.duha, isSunnah: true),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCard(context, fardPrayers, nextMs,
            _nextProgress(view.today, schedule, nextMs),),
        const SizedBox(height: 8),
        _buildCard(context, sunnahPrayers, nextMs, null),
      ],
    );
  }

  /// Progress from the previous event to the next one (0–1), derived
  /// chronologically from today's ordered events. Null when it can't be
  /// determined (e.g. before Fajr, where "previous" was yesterday's Isha).
  /// Static per build — refreshes on nudge, like the highlight.
  static double? _nextProgress(
      DateTime now, PrayerSchedule schedule, int nextMs,) {
    DateTime? prev;
    for (final event in schedule.ordered) {
      if (!event.time.isAfter(now)) {
        prev = event.time;
      }
    }
    final prevMs = prev?.millisecondsSinceEpoch;
    if (prevMs == null || nextMs <= prevMs) return null;
    final nowMs = now.millisecondsSinceEpoch;
    if (nowMs < prevMs) return null;
    return ((nowMs - prevMs) / (nextMs - prevMs)).clamp(0.0, 1.0);
  }

  /// Time-of-day tint for each prayer medallion. Fixed hues read well on
  /// both light and dark backgrounds.
  static (Color, Color) _tintFor(PrayerEventId? id) => switch (id) {
        PrayerEventId.fajr => (const Color(0xFF7C6AAE), const Color(0xFF7C6AAE)),
        PrayerEventId.sunrise =>
          (const Color(0xFFE8823A), const Color(0xFFE8823A)),
        PrayerEventId.dhuhr =>
          (const Color(0xFFB8860B), const Color(0xFFB8860B)),
        PrayerEventId.asr => (const Color(0xFFD97A2B), const Color(0xFFD97A2B)),
        PrayerEventId.maghrib =>
          (const Color(0xFFC14A3A), const Color(0xFFC14A3A)),
        PrayerEventId.isha => (const Color(0xFF4A5AA8), const Color(0xFF4A5AA8)),
        null => (const Color(0xFF757575), const Color(0xFF757575)),
      };

  Widget _buildCard(
    BuildContext context,
    List<_PrayerTime> prayers,
    int nextMs,
    double? nextProgress,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < prayers.length; i++) ...[
              _buildRow(
                context,
                prayers[i],
                isNext: prayers[i].time?.millisecondsSinceEpoch == nextMs,
                progress:
                    prayers[i].time?.millisecondsSinceEpoch == nextMs
                        ? nextProgress
                        : null,
              ),
              if (i != prayers.length - 1)
                Divider(
                  height: 1,
                  indent: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.15),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // --- REFACTORED: This is now a "dumb" builder method ---
  // It receives all the data it needs and contains NO reactive code.
  Widget _buildRow(
    BuildContext context,
    _PrayerTime prayer, {
    required bool isNext,
    required double? progress,
  }) {
    final Color? rowColor = isNext
        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
        : null;
    final (medallionBg, medallionFg) = _tintFor(prayer.id);

    return Container(
      decoration: BoxDecoration(color: rowColor),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      // Row is explicitly RTL so the medallion — the first child — lands
      // on the right of the name.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              if (prayer.icon != null)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: medallionBg.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    prayer.icon,
                    size: 20,
                    color: medallionFg,
                    semanticLabel: prayer.name,
                  ),
                ),
              if (prayer.icon != null) const SizedBox(width: 10),
              Expanded(
                child: InlineTextWidget(
                  prayer.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isNext
                        ? FontWeight.bold
                        : (prayer.isSunnah
                            ? FontWeight.w500
                            : FontWeight.w600),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              InlineTextWidget(
                _formatTime(prayer.time),
                style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.normal,),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          if (isNext && progress != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to build the placeholder table to avoid code duplication
  Widget _buildPlaceholderTable(BuildContext context) {
    const fardPrayers = [
      _PrayerTime('المغرب', null,
          id: PrayerEventId.maghrib, icon: LucideIcons.sunset,),
      _PrayerTime('العشاء', null,
          id: PrayerEventId.isha, icon: LucideIcons.moon,),
      _PrayerTime('الفجر', null,
          id: PrayerEventId.fajr, icon: LucideIcons.sunMoon,),
      _PrayerTime('الشروق', null,
          id: PrayerEventId.sunrise, icon: LucideIcons.sunrise,),
      _PrayerTime('الظهر', null,
          id: PrayerEventId.dhuhr, icon: LucideIcons.sun,),
      _PrayerTime('العصر', null,
          id: PrayerEventId.asr, icon: LucideIcons.cloudSun,),
    ];
    const sunnahPrayers = [
      _PrayerTime('منتصف الليل', null, isSunnah: true),
      _PrayerTime('الثلث الأخير', null, isSunnah: true),
      _PrayerTime('الضحى', null, isSunnah: true),
    ];

    // No next prayer while unconfigured: -1 matches nothing, no progress bar.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCard(context, fardPrayers, -1, null),
        const SizedBox(height: 8),
        _buildCard(context, sunnahPrayers, -1, null),
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
  final PrayerEventId? id;
  final IconData? icon;

  const _PrayerTime(this.name, this.time,
      {this.isSunnah = false, this.id, this.icon,});
}
