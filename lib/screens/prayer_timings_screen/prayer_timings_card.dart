import 'package:intl/intl.dart' as intl;
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:text_responsive/text_responsive.dart';
import 'package:timezone/timezone.dart' as tz;

class PrayerTimingsCard extends StatelessWidget {
  const PrayerTimingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GetBuilder<PrayerTimingsController>(
          builder: (controller) {
            // Use timezone-aware prayer times instead of raw prayerTimes
            final timezonedPrayerTimes = PrayerTimeings.getAllPrayerTimes();

            if (timezonedPrayerTimes == null) {
              return const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'برجاء تحديد الموقع لعرض المواقيت',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              );
            }

            // Calculate Sunnah times using timezone-aware times
            final sunnahTimes = _calculateSunnahTimes(timezonedPrayerTimes);

            final prayers = [
              _PrayerTime('المغرب', timezonedPrayerTimes['maghrib']!,
                  isMainPrayer: true, englishName: 'maghrib'),
              _PrayerTime('العشاء', timezonedPrayerTimes['isha']!,
                  isMainPrayer: true, englishName: 'isha'),
              _PrayerTime('منتصف الليل', sunnahTimes['middleOfNight']!,
                  isMainPrayer: false),
              _PrayerTime('الثلث الأخير', sunnahTimes['lastThirdOfNight']!,
                  isMainPrayer: false),
              _PrayerTime('الفجر', timezonedPrayerTimes['fajr']!,
                  isMainPrayer: true, englishName: 'fajr'),
              _PrayerTime('الشروق', timezonedPrayerTimes['sunrise']!,
                  isMainPrayer: true, englishName: 'sunrise'),
              _PrayerTime('الضحى', sunnahTimes['duha']!, isMainPrayer: false),
              _PrayerTime('الظهر', timezonedPrayerTimes['dhuhr']!,
                  isMainPrayer: true, englishName: 'dhuhr'),
              _PrayerTime('العصر', timezonedPrayerTimes['asr']!,
                  isMainPrayer: true, englishName: 'asr'),
            ];

            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1),
                },
                children: prayers
                    .map((prayer) => _buildTableRow(
                          context,
                          prayer,
                          controller, // Pass controller to access reactive values
                        ))
                    .toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  TableRow _buildTableRow(
    BuildContext context,
    _PrayerTime prayer,
    PrayerTimingsController controller, // Add controller parameter
  ) {
    // Use Obx to make this reactive to timeLeftForNextPrayer changes
    return TableRow(
      children: [
        Obx(() {
          // Get current next prayer to highlight it reactively
          final nextPrayerResult = controller.timeLeftForNextPrayer.value;
          final nextPrayerName = _getArabicPrayerName(nextPrayerResult.$2);
          final bool isNextPrayer = prayer.name == nextPrayerName;

          Color? rowColor;
          if (isNextPrayer) {
            rowColor =
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3);
          }

          return Container(
            decoration: BoxDecoration(
              color: rowColor,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: InlineTextWidget(
                      prayer.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: prayer.isMainPrayer
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        Obx(() {
          // Get current next prayer to highlight it reactively
          final nextPrayerResult = controller.timeLeftForNextPrayer.value;
          final nextPrayerName = _getArabicPrayerName(nextPrayerResult.$2);
          final bool isNextPrayer = prayer.name == nextPrayerName;

          Color? rowColor;
          if (isNextPrayer) {
            rowColor =
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3);
          }

          return Container(
            decoration: BoxDecoration(
              color: rowColor,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: InlineTextWidget(
                _formatTime(prayer.time),
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }),
      ],
    );
  }

  String _formatTime(tz.TZDateTime time) {
    final period = (time.hour >= 12) ? 'م' : 'ص';
    final format = intl.DateFormat('hh:mm', 'en_US');
    return '${format.format(time)} $period';
  }

  // Calculate Sunnah times using timezone-aware prayer times
  Map<String, tz.TZDateTime> _calculateSunnahTimes(
      Map<String, tz.TZDateTime> prayerTimes) {
    final maghrib = prayerTimes['maghrib']!;
    final fajr = prayerTimes['fajr']!;
    final sunrise = prayerTimes['sunrise']!;

    // Calculate middle of the night (between Maghrib and Fajr)
    final nightDuration = fajr.add(const Duration(days: 1)).difference(maghrib);
    final middleOfNight =
        maghrib.add(Duration(milliseconds: nightDuration.inMilliseconds ~/ 2));

    // Calculate last third of the night
    final lastThirdOfNight = fajr
        .subtract(Duration(milliseconds: nightDuration.inMilliseconds ~/ 3));

    // Calculate Duha time (20 minutes after sunrise)
    final duhaTime = sunrise.add(const Duration(minutes: 20));

    return {
      'middleOfNight': middleOfNight,
      'lastThirdOfNight': lastThirdOfNight,
      'duha': duhaTime,
    };
  }

  // Convert English prayer names to Arabic
  String _getArabicPrayerName(String englishName) {
    switch (englishName.toLowerCase()) {
      case 'fajr':
      case 'الفجر':
        return 'الفجر';
      case 'sunrise':
      case 'الشروق':
        return 'الشروق';
      case 'dhuhr':
      case 'الظهر':
        return 'الظهر';
      case 'asr':
      case 'العصر':
        return 'العصر';
      case 'maghrib':
      case 'المغرب':
        return 'المغرب';
      case 'isha':
      case 'العشاء':
        return 'العشاء';
      default:
        return englishName;
    }
  }
}

class _PrayerTime {
  final String name;
  final tz.TZDateTime time;
  final bool isMainPrayer;
  final String? englishName;

  const _PrayerTime(
    this.name,
    this.time, {
    this.isMainPrayer = false,
    this.englishName,
  });
}
