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
    // Get the controller once outside the reactive builder.
    final PrayerTimingsController controller =
        Get.find<PrayerTimingsController>();

    return Card(
      elevation: 4,
      // --- REFACTORED: Use a single Obx wrapper for the whole card ---
      child: Obx(() {
        // 1. Read the observable variables needed for the UI.
        //    Obx will now listen to changes in BOTH of these.
        final prayerTimings = controller.prayerTimings.value;
        final nextPrayerTuple = controller.timeLeftForNextPrayer.value;
        final nextPrayerName = _getArabicPrayerName(nextPrayerTuple.$2);

        // --- Use your preferred placeholder logic ---
        if (prayerTimings == null) {
          return _buildPlaceholderTable(context); // Build the placeholder table
        }

        // If we have prayer times, build the real table.
        final timezonedPrayerTimes = PrayerTimeings.getAllPrayerTimes();
        if (timezonedPrayerTimes == null) {
          // This is an edge case, but good to handle.
          return _buildPlaceholderTable(context);
        }

        final sunnahTimes = _calculateSunnahTimes(timezonedPrayerTimes);
        final placeholderTime = tz.TZDateTime.from(DateTime(1, 1, 1), tz.local);

        final prayers = [
          _PrayerTime('المغرب', timezonedPrayerTimes['maghrib']!),
          _PrayerTime('العشاء', timezonedPrayerTimes['isha']!),
          _PrayerTime(
              'منتصف الليل', sunnahTimes?['middleOfNight'] ?? placeholderTime,
              isSunnah: true),
          _PrayerTime('الثلث الأخير',
              sunnahTimes?['lastThirdOfNight'] ?? placeholderTime,
              isSunnah: true),
          _PrayerTime('الفجر', timezonedPrayerTimes['fajr']!),
          _PrayerTime('الشروق', timezonedPrayerTimes['sunrise']!),
          _PrayerTime('الضحى', sunnahTimes?['duha'] ?? placeholderTime,
              isSunnah: true),
          _PrayerTime('الظهر', timezonedPrayerTimes['dhuhr']!),
          _PrayerTime('العصر', timezonedPrayerTimes['asr']!),
        ];

        return Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
            },
            // The map now passes the calculated `isNextPrayer` boolean.
            children: prayers.map((prayer) {
              final isNextPrayer = prayer.name == nextPrayerName;
              return _buildTableRow(context, prayer, isNextPrayer);
            }).toList(),
          ),
        );
      }),
    );
  }

  // --- REFACTORED: This is now a "dumb" builder method ---
  // It receives all the data it needs and contains NO reactive code.
  TableRow _buildTableRow(
      BuildContext context, _PrayerTime prayer, bool isNextPrayer) {
    final Color? rowColor = isNextPrayer
        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
        : null;
    final border = BorderSide(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        width: 0.5);

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
                fontWeight: FontWeight.normal),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // Helper method to build the placeholder table to avoid code duplication
  Widget _buildPlaceholderTable(BuildContext context) {
    final placeholderTime = tz.TZDateTime.from(DateTime(1, 1, 1), tz.local);
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

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
        children: prayers
            .map((prayer) => _buildTableRow(context, prayer, false))
            .toList(),
      ),
    );
  }

  String _formatTime(tz.TZDateTime time) {
    if (time.year == 1) {
      return '--:--';
    }
    final period = (time.hour >= 12) ? 'م' : 'ص';
    final format = intl.DateFormat('hh:mm', 'en_US');
    return '${format.format(time)} $period';
  }

  Map<String, tz.TZDateTime>? _calculateSunnahTimes(
      Map<String, tz.TZDateTime> todaysPrayerTimes) {
    final maghrib = todaysPrayerTimes['maghrib'];
    final sunrise = todaysPrayerTimes['sunrise'];
    if (maghrib == null || sunrise == null) return null;

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowsPrayers =
        PrayerTimeings.getPrayersTimings(forDate: tomorrow);
    final fajrTomorrow = tomorrowsPrayers?.fajr;
    if (fajrTomorrow == null) return null;

    final nightDuration =
        tz.TZDateTime.from(fajrTomorrow, tz.local).difference(maghrib);
    final middleOfNight =
        maghrib.add(Duration(milliseconds: nightDuration.inMilliseconds ~/ 2));
    final lastThirdOfNight = tz.TZDateTime.from(fajrTomorrow, tz.local)
        .subtract(Duration(milliseconds: nightDuration.inMilliseconds ~/ 3));
    final duhaTime = sunrise.add(const Duration(minutes: 20));

    return {
      'middleOfNight': middleOfNight,
      'lastThirdOfNight': lastThirdOfNight,
      'duha': duhaTime
    };
  }

  String _getArabicPrayerName(String englishName) {
    switch (englishName.toLowerCase()) {
      case 'fajr':
        return 'الفجر';
      case 'sunrise':
        return 'الشروق';
      case 'dhuhr':
        return 'الظهر';
      case 'asr':
        return 'العصر';
      case 'maghrib':
        return 'المغرب';
      case 'isha':
        return 'العشاء';
      default:
        return englishName;
    }
  }
}

class _PrayerTime {
  final String name;
  final tz.TZDateTime time;
  final bool isSunnah;

  const _PrayerTime(this.name, this.time, {this.isSunnah = false});
}
