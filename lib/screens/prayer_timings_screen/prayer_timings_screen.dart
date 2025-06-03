import 'dart:async';
import 'dart:math';
import 'package:aldurar_alnaqia/MyDrawer.dart';
import 'package:aldurar_alnaqia/widgets/main_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/adjust_hijri_day_dialogBox.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/manual_coordination_form.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/hijri_date_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';
import 'package:text_responsive/text_responsive.dart';

class PrayerTimingsScreen extends StatelessWidget {
  const PrayerTimingsScreen({super.key});

  static final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    // Initialize controllers here - only once when screen is built
    Get.lazyPut(() => PrayerTimingsController(), fenix: true);
    Get.lazyPut(() => HijriOffsetController(), fenix: true);

    Get.lazyPut(() => GlobalDrawerController());
// Get the global drawer controller
    final drawerController = Get.find<GlobalDrawerController>();

    // Register this scaffold key
    drawerController.registerScaffoldKey(_scaffoldKey);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: 'فتح القائمة'),
      ),
      drawer: const MyDrawer(),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _ActionButtonsRow(),
            SizedBox(height: 20),
            _DateDisplayRow(),
            SizedBox(height: 20),
            _NextPrayerCard(),
            SizedBox(height: 20),
            _PrayerTimingsCard(),
          ],
        ),
      ),
    );
  }
}

class _ActionButtonsRow extends StatelessWidget {
  const _ActionButtonsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _ActionButton(
            onPressed: () => _showManualCoordinatesDialog(context),
            label: 'إعدادات المواقيت',
            icon: Icons.settings,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            onPressed: () => _showHijriAdjustDialog(context),
            label: 'تعديل اليوم الهجرى',
            icon: Icons.date_range,
          ),
        ),
      ],
    );
  }

  void _showManualCoordinatesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ManualCoordinatesForm(),
    );
  }

  void _showHijriAdjustDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AdjustHijriDayDialogbox(),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  const _ActionButton({
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      label: InlineTextWidget(label, textAlign: TextAlign.center),
      icon: Icon(icon),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _DateDisplayRow extends StatelessWidget {
  const _DateDisplayRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const Expanded(
          child: Card(
              child: Padding(
            padding: EdgeInsets.all(12.0),
            child: Center(child: _GeorgianDateWidget()),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Center(
                  child: GetBuilder<HijriOffsetController>(
                    builder: (controller) {
                      final date = controller.getHijriDayByoffest();
                      return HijriDateWidget(date: date);
                    },
                  ),
                )),
          ),
        ),
      ],
    );
  }
}

class _GeorgianDateWidget extends StatelessWidget {
  const _GeorgianDateWidget();

  static const Map<int, String> _arabicMonths = {
    1: 'يناير',
    2: 'فبراير',
    3: 'مارس',
    4: 'أبريل',
    5: 'مايو',
    6: 'يونيو',
    7: 'يوليو',
    8: 'أغسطس',
    9: 'سبتمبر',
    10: 'أكتوبر',
    11: 'نوفمبر',
    12: 'ديسمبر',
  };

  String _formatDate(DateTime date) {
    return '${date.day} ${_arabicMonths[date.month]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(
        const Duration(minutes: 1),
        (_) => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        return InlineTextWidget(
          style: Theme.of(context).textTheme.titleMedium,
          _formatDate(snapshot.data!),
          textDirection: TextDirection.rtl,
        );
      },
    );
  }
}

class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: _NextPrayerCountdown(),
      ),
    );
  }
}

class _NextPrayerCountdown extends StatelessWidget {
  const _NextPrayerCountdown();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PrayerTimingsController>(
      builder: (controller) {
        if (controller.prayerTimings == null) {
          return const Text(
            'برجاء تحديد الموقع أولاً',
            style: TextStyle(fontSize: 16),
          );
        }

        return StreamBuilder<DateTime>(
          stream: Stream.periodic(
            const Duration(seconds: 1),
            (_) => DateTime.now(),
          ),
          initialData: DateTime.now(),
          builder: (context, snapshot) {
            final result = PrayerTimeings.timeLeftForNextPrayer();
            final timeLeft = result.$1;
            final prayerName = result.$2;

            return Column(
              children: [
                Text(
                  prayerName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'بعد ${_formatDuration(timeLeft)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}

class _PrayerTimingsCard extends StatelessWidget {
  const _PrayerTimingsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: _PrayerTimingsTable(),
      ),
    );
  }
}

class _PrayerTimingsTable extends StatelessWidget {
  const _PrayerTimingsTable();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PrayerTimingsController>(
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
        final duhaTime = prayerTimes.sunrise.add(const Duration(minutes: 20));

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
    );
  }

  TableRow _buildTableRow(BuildContext context, _PrayerTime prayer) {
    return TableRow(
      decoration: BoxDecoration(
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

class ScaleSize {
  static double textScaleFactor(BuildContext context,
      {double maxTextScaleFactor = 2}) {
    final width = MediaQuery.of(context).size.width;
    double val = (width / 1400) * maxTextScaleFactor;
    return max(1, min(val, maxTextScaleFactor));
  }
}
