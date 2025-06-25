// lib/widgets/hijri_date_widget.dart

import 'dart:async';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/adjust_hijri_day_dialogBox.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hijri/hijri_calendar.dart';
// Make sure to import your other controllers and utility classes
import 'package:timezone/timezone.dart' as tz;

// TODO: make it truely reactive(change after maghrib)
class HijriDateWidget extends StatefulWidget {
  const HijriDateWidget({super.key});

  @override
  State<HijriDateWidget> createState() => _HijriDateWidgetState();
}

class _HijriDateWidgetState extends State<HijriDateWidget> {
  // Timer for scheduling the update at Maghrib.
  Timer? _maghribTimer;
  // The currently displayed Hijri date.
  HijriCalendar? _hijriDate;

  // GetX controllers.
  final HijriOffsetController hc = Get.find<HijriOffsetController>();
  final PrayerTimingsController pc = Get.find<PrayerTimingsController>();

  // A subscription to listen to GetX controller changes.
  late final StreamSubscription _prayerTimesSubscription;

  @override
  void initState() {
    super.initState();

    // 1. Set the initial date immediately.
    _updateHijriDate();

    // 2. Listen for any changes in prayer timings (e.g., user changes location).
    //    When they change, reset and reschedule our timer.
    _prayerTimesSubscription = pc.prayerTimings.listen((_) {
      _resetAndScheduleUpdate();
    });

    // 3. Listen for changes in the manual Hijri offset.
    ever(hc.offset, (_) => _updateHijriDate());

    // 4. Schedule the first update for the next Maghrib.
    // We add a small delay to ensure the prayer times have been initialized.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _resetAndScheduleUpdate();
      }
    });
  }

  @override
  void dispose() {
    // Clean up to prevent memory leaks.
    _maghribTimer?.cancel();
    _prayerTimesSubscription.cancel();
    super.dispose();
  }

  /// Updates the displayed Hijri date based on the offset controller.
  void _updateHijriDate() {
    if (mounted) {
      setState(() {
        _hijriDate = hc.getHijriDayByoffest();
      });
    }
  }

  /// This is the core logic. It cancels any old timer and schedules a new one
  /// for the next upcoming Maghrib time.
  void _resetAndScheduleUpdate() {
    // Cancel any existing timer before creating a new one.
    _maghribTimer?.cancel();

    // Get today's prayer times from the controller.
    final todaysPrayers = pc.prayerTimings.value;
    if (todaysPrayers?.maghrib == null) {
      print(
          "HijriDateWidget: Maghrib time not available. Cannot schedule update.");
      return; // Can't schedule if we don't have the time.
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime maghribTime =
        tz.TZDateTime.from(todaysPrayers!.maghrib!, tz.local);

    // Check if today's Maghrib has already passed.
    if (maghribTime.isBefore(now)) {
      // If it passed, we need to get *tomorrow's* Maghrib time.
      final tomorrowsPrayers = PrayerTimeings.getPrayersTimings(
        forDate: now.add(const Duration(days: 1)),
      );
      if (tomorrowsPrayers?.maghrib == null) {
        print("HijriDateWidget: Could not calculate tomorrow's Maghrib time.");
        return;
      }
      maghribTime = tz.TZDateTime.from(tomorrowsPrayers!.maghrib!, tz.local);
    }

    // Calculate the duration until the next Maghrib.
    final timeUntilMaghrib = maghribTime.difference(now);

    print(
        "HijriDateWidget: Next Hijri day update scheduled in $timeUntilMaghrib");

    // Set a timer that will fire exactly at Maghrib.
    _maghribTimer = Timer(timeUntilMaghrib, () {
      print("HijriDateWidget: Maghrib has arrived! Updating Hijri date.");
      // When the timer fires:
      // 1. Update the date on the screen.
      _updateHijriDate();
      // 2. Schedule the *next* update for the following day's Maghrib.
      _resetAndScheduleUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    // We use Obx to react to changes in the HijriOffsetController,
    // although the internal setState also handles updates.
    // This provides a fallback if setState is missed.
    if (_hijriDate == null) {
      return const SizedBox.shrink();
    }
    return Text(
      '${_hijriDate!.hDay} ${_hijriDate!.longMonthName} ${_hijriDate!.hYear}',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}
