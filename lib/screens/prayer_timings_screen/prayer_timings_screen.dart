import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/adjust_hijri_day_dialogBox.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/manual_coordination_form.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/hijri_date_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';

class PrayerTimingsScreen extends StatelessWidget {
  const PrayerTimingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('مواقيت الصلاة'),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // this should be on dialog (adjust hijri date.).confirm btn
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (builder) => ManualCoordinatesForm());
                    },
                    label: const Text('إعدادات المواقيت'),
                    icon: const Icon(Icons.settings),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (builder) {
                            return const AdjustHijriDayDialogbox();
                          });
                    },
                    label: const Text('تعديل اليوم الهجرى'),
                    icon: const Icon(Icons.date_range),
                  ),
                ],
              ),
              const SizedBox(height: 10),
//
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const NextPrayerWidget(),

                  // TODO: update this whenever prayerTimings changes
                  // GetBuilder<PrayerTimingsController>(
                  //     init: PrayerTimingsController(),
                  //     builder: (pc) {
                  //       return
                  // },
                  GetBuilder<HijriOffsetController>(
                      init: HijriOffsetController(),
                      builder: (c) {
                        final date = c.getHijriDayByoffest();
                        return HijriDateWidget(date: date);
                      }),
                ],
              ),
//
              const PrayerTimingsWidget(),
            ],
          ),
        ));
  }
}

class NextPrayerWidget extends StatefulWidget {
  const NextPrayerWidget({
    super.key,
  });

  @override
  State<NextPrayerWidget> createState() => _NextPrayerWidgetState();
}

class _NextPrayerWidgetState extends State<NextPrayerWidget> {
  late Timer timer;

  final pc = Get.put(PrayerTimingsController());
  late Duration timeLeft;
  late String prayerName;

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  void initState() {
    timeLeft = PrayerTimeings.timeLeftForNextPrayer().$1;
    prayerName = PrayerTimeings.timeLeftForNextPrayer().$2;

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (timeLeft.inSeconds == 0) {
        setState(() {
          timeLeft = PrayerTimeings.timeLeftForNextPrayer().$1;
          prayerName = PrayerTimeings.timeLeftForNextPrayer().$2;
        });
      } else {
        setState(() {
          timeLeft = PrayerTimeings.timeLeftForNextPrayer().$1;

          // timeLeft = timeLeft - const Duration(seconds: 1);
        });
      }
    });

    ever(pc.timeLeftForNextPrayer, (_) {
      setState(() {
        timeLeft = PrayerTimeings.timeLeftForNextPrayer().$1;
        prayerName = PrayerTimeings.timeLeftForNextPrayer().$2;
      });
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$prayerName بعد ${timeLeft.toString().split('.').first}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

class PrayerTimingsWidget extends StatelessWidget {
  const PrayerTimingsWidget({super.key});
  static late PrayerTimes? prayerTimes;

  TableRow _buildTableRow(String name, DateTime? time) {
    late final String period;
    late final intl.DateFormat customFormat;
    if (time != null) {
      period = (time.hour >= 12) ? 'م' : 'ص';
      customFormat = intl.DateFormat('hh:mm $period', 'en_US');
    }

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(name, style: const TextStyle(fontSize: 16)),
        ),
        if (time == null) ...{
          const Text('00:00', style: TextStyle(fontSize: 16)),
        } else ...{
          Text(
            customFormat.format(time),
            style: const TextStyle(fontSize: 16),
          )
        },
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PrayerTimingsController>(
        init: PrayerTimingsController(),
        builder: (c) {
          prayerTimes = c.prayerTimings;
          SunnahTimes? sunnahTimes;
          if (prayerTimes != null) {
            sunnahTimes = SunnahTimes(prayerTimes!);
          }
          final duha = prayerTimes?.sunrise.add(const Duration(minutes: 20));

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              if (prayerTimes == null) ...{
                Text(
                  'برجاء تحديد الموقع',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              } else ...{
                Text(
                  'مواقيت الصلاة',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              },
              const SizedBox(height: 10),
              Table(
                columnWidths: {
                  0: FixedColumnWidth(MediaQuery.sizeOf(context).width / 3),
                  1: FixedColumnWidth(MediaQuery.sizeOf(context).width / 3)
                },
                border: TableBorder(
                  horizontalInside: BorderSide(
                      width: 1,
                      color: Theme.of(context).colorScheme.secondaryFixed),
                ),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  _buildTableRow('المغرب', prayerTimes?.maghrib),
                  _buildTableRow('العشاء', prayerTimes?.isha),
                  _buildTableRow('منتصف الليل', sunnahTimes?.middleOfTheNight),
                  _buildTableRow(
                      'الثلث الأخير', sunnahTimes?.lastThirdOfTheNight),
                  _buildTableRow('الفجر', prayerTimes?.fajr),
                  _buildTableRow('الشروق', prayerTimes?.sunrise),
                  _buildTableRow('الضحى', duha),
                  _buildTableRow('الظهر', prayerTimes?.dhuhr),
                  _buildTableRow('العصر', prayerTimes?.asr),
                ],
              ),
            ],
          );
        });
  }
}
