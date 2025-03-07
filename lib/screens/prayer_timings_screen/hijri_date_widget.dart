import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:yosria/screens/prayer_timings_screen/adjust_hijri_day_dialogBox.dart';
import 'package:yosria/screens/prayer_timings_screen/prayerTimingsController.dart';

class HijriDateWidget extends StatefulWidget {
  const HijriDateWidget({super.key, required this.date});
  final HijriCalendar? date;
  @override
  State<HijriDateWidget> createState() => _HijriDateWidgetState();
}

class _HijriDateWidgetState extends State<HijriDateWidget> {
  late Timer _timerMaghrib;
  late HijriCalendar? hijriDate = widget.date;

  final hc = Get.find<HijriOffsetController>();
  final pc = Get.find<PrayerTimingsController>();

  void _scheduleNextUpdate() {
    final now = DateTime.now();
    final maghrib = PrayerTimeings.getPrayersTimings()?.maghrib;
    if (maghrib == null) {
      return;
    }

    _timerMaghrib = Timer(maghrib.difference(now), () {
      setState(() {
        hijriDate = hc.getHijriDayByoffest();
      });
    });
  }

  @override
  void initState() {
    ever(hc.offset, (_) {
      hijriDate = hc.getHijriDayByoffest();
    });
    // TODO: update this whenever prayerTimings changes
    // ever(pc.prayerTimings.maghrib, (_) {
    //   hijriDate = hc.getHijriDayByoffest();
    // });
    super.initState();
    _scheduleNextUpdate();
  }

  //
  @override
  void dispose() {
    _timerMaghrib.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
        '${hijriDate?.hDay} ${hijriDate?.longMonthName} ${hijriDate?.hYear}',
        style: Theme.of(context).textTheme.titleMedium!);
  }
}
