import 'package:intl/intl.dart' as intl;
import 'package:adhan/adhan.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:text_responsive/text_responsive.dart';

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
            final prayerTimes = controller.prayerTimings;

            if (prayerTimes == null) {
              return const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'برجاء تحديد الموقع لعرض المواقيت',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              );
            }

            final sunnahTimes = SunnahTimes(prayerTimes);
            final duhaTime =
                prayerTimes.sunrise.add(const Duration(minutes: 20));

            final prayers = [
              _PrayerTime('المغرب', prayerTimes.maghrib),
              _PrayerTime('العشاء', prayerTimes.isha),
              _PrayerTime('منتصف الليل', sunnahTimes.middleOfTheNight),
              _PrayerTime('الثلث الأخير', sunnahTimes.lastThirdOfTheNight),
              _PrayerTime('الفجر', prayerTimes.fajr),
              _PrayerTime('الشروق', prayerTimes.sunrise),
              _PrayerTime('الضحى', duhaTime),
              _PrayerTime('الظهر', prayerTimes.dhuhr),
              _PrayerTime('العصر', prayerTimes.asr),
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
                    .map((prayer) => _buildTableRow(context, prayer))
                    .toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  TableRow _buildTableRow(BuildContext context, _PrayerTime prayer) {
    // Highlight main prayers differently, or add an icon, or based on prayerData.isMainPrayer
    // For now, just using the name and time.

// TODO: refactor this
    final result = PrayerTimeings.timeLeftForNextPrayer();
    final prayerName = result.$2;
    final bool isNextPrayer = prayer.name == prayerName;

    final Color? rowColor = isNextPrayer
        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
        : null;

    return TableRow(
      decoration: BoxDecoration(
        color: rowColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: InlineTextWidget(
            prayer.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: InlineTextWidget(
            _formatTime(prayer.time),
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final period = (time.hour >= 12) ? 'م' : 'ص';
    final format = intl.DateFormat('hh:mm', 'en_US');
    return '${format.format(time)} $period';
  }
}

class _PrayerTime {
  final String name;
  final DateTime time;

  const _PrayerTime(this.name, this.time);
}
