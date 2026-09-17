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
/// is highlighted. The prev → next progress bar lives under the countdown
/// in [NextPrayerCountdown], not here.
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
      _PrayerTime('الضحى', sunnah?.duha,
          isSunnah: true,
          assetPath: 'assets/imgs/sunnah_duha.png',
          icon: LucideIcons.sun,
          tint: const Color(0xFFE8823A),),
      _PrayerTime('منتصف الليل', sunnah?.middleOfNight,
          isSunnah: true,
          assetPath: 'assets/imgs/sunnah_midnight.png',
          icon: LucideIcons.moonStar,
          tint: const Color(0xFF4A5AA8),),
      _PrayerTime('الثلث الأخير', sunnah?.lastThirdOfNight,
          isSunnah: true,
          assetPath: 'assets/imgs/sunnah_last_third.png',
          icon: LucideIcons.moonStar,
          tint: const Color(0xFF7C6AAE),),
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
  ) {
    return Card(
      elevation: 1,
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
  }) {
    final Color? rowColor = isNext
        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
        : null;
    final (medallionBg, medallionFg) =
        prayer.tint != null ? (prayer.tint!, prayer.tint!) : _tintFor(prayer.id);
    final hasVisual = prayer.icon != null || prayer.assetPath != null;

    return Container(
      decoration: BoxDecoration(color: rowColor),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      // Row is explicitly RTL so the medallion — the first child — lands
      // on the right of the name.
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          if (hasVisual)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: medallionBg.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: prayer.assetPath != null
                    ? Image.asset(
                        prayer.assetPath!,
                        width: 22,
                        height: 22,
                        color: medallionFg,
                        colorBlendMode: BlendMode.srcIn,
                        semanticLabel: prayer.name,
                        // New files need a full restart (not hot reload) to
                        // enter the asset bundle; fall back to the Lucide
                        // icon instead of the red broken-image box.
                        errorBuilder: (context, error, stackTrace) => Icon(
                          prayer.icon,
                          size: 20,
                          color: medallionFg,
                          semanticLabel: prayer.name,
                        ),
                      )
                    : Icon(
                        prayer.icon,
                        size: 20,
                        color: medallionFg,
                        semanticLabel: prayer.name,
                      ),
              ),
            ),
          if (hasVisual) const SizedBox(width: 10),
          Expanded(
            child: InlineTextWidget(
              prayer.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isNext
                    ? FontWeight.bold
                    : (prayer.isSunnah ? FontWeight.w500 : FontWeight.w600),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          InlineTextWidget(
            _formatTime(prayer.time),
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'monospace',
              fontWeight: FontWeight.normal,
            ),
            textAlign: TextAlign.center,
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
      _PrayerTime('الضحى', null,
          isSunnah: true,
          assetPath: 'assets/imgs/sunnah_duha.png',
          icon: LucideIcons.sun,
          tint: Color(0xFFE8823A),),
      _PrayerTime('منتصف الليل', null,
          isSunnah: true,
          assetPath: 'assets/imgs/sunnah_midnight.png',
          icon: LucideIcons.moonStar,
          tint: Color(0xFF4A5AA8),),
      _PrayerTime('الثلث الأخير', null,
          isSunnah: true,
          assetPath: 'assets/imgs/sunnah_last_third.png',
          icon: LucideIcons.moonStar,
          tint: Color(0xFF7C6AAE),),
    ];

    // No next prayer while unconfigured: -1 matches nothing.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCard(context, fardPrayers, -1),
        const SizedBox(height: 8),
        _buildCard(context, sunnahPrayers, -1),
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
  final String? assetPath;
  final Color? tint;

  const _PrayerTime(this.name, this.time,
      {this.isSunnah = false, this.id, this.icon, this.assetPath, this.tint,});
}
