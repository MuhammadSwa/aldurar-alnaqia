// Modified ArabicDayNameWidget with consistent sizing
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';

class ArabicDayNameWidget extends StatefulWidget {
  const ArabicDayNameWidget({super.key});

  @override
  State<ArabicDayNameWidget> createState() => _ArabicDayNameWidgetState();
}

class _ArabicDayNameWidgetState extends State<ArabicDayNameWidget> {
  static const Map<int, String> _arabicDayNames = {
    7: 'الأحد',
    1: 'الإثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
    6: 'السبت',
  };

  String? _currentDayName;
  Timer? _updateTimer;
  final PrayerTimingsController pc = Get.find<PrayerTimingsController>();
  late final StreamSubscription _prayerTimesSubscription;

  @override
  void initState() {
    super.initState();
    _prayerTimesSubscription = pc.prayerTimings.listen((_) {
      _updateDayAndScheduleNext();
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _updateDayAndScheduleNext();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _prayerTimesSubscription.cancel();
    super.dispose();
  }

  void _updateDayAndScheduleNext() {
    _updateTimer?.cancel();
    final now = tz.TZDateTime.now(tz.local);
    final todaysPrayers = pc.prayerTimings.value;

    if (todaysPrayers?.maghrib == null) {
      if (mounted) {
        setState(() {
          _currentDayName = _arabicDayNames[now.weekday];
        });
      }
      return;
    }

    DateTime effectiveDate = now;
    final maghribTime = tz.TZDateTime.from(todaysPrayers!.maghrib!, tz.local);

    if (now.isAfter(maghribTime)) {
      effectiveDate = now.add(const Duration(days: 1));
    }

    if (mounted) {
      setState(() {
        _currentDayName = _arabicDayNames[effectiveDate.weekday] ?? '...';
      });
    }

    tz.TZDateTime nextMaghrib = maghribTime;
    if (now.isAfter(maghribTime)) {
      final tomorrowsPrayers = PrayerTimeings.getPrayersTimings(
          forDate: now.add(const Duration(days: 1)));
      if (tomorrowsPrayers?.maghrib != null) {
        nextMaghrib = tz.TZDateTime.from(tomorrowsPrayers!.maghrib!, tz.local);
      } else {
        return;
      }
    }

    final timeUntilNextMaghrib = nextMaghrib.difference(now);
    _updateTimer = Timer(timeUntilNextMaghrib, () {
      _updateDayAndScheduleNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentDayName == null) {
      return const SizedBox(
        height: 120, // Same height as NextPrayerCountdown
        child: Card(
          elevation: 4,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return SizedBox(
      height: 100, // Fixed height to match NextPrayerCountdown
      child: Card(
        elevation: 4,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Text(
              _currentDayName!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 30,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
