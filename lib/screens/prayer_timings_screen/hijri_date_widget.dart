// lib/widgets/hijri_date_widget.dart

import 'dart:async';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/adjust_hijri_day_dialog_box.dart'
    show hijriDayWithOffset;
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
// Make sure to import your other controllers and utility classes
import 'package:timezone/timezone.dart' as tz;
import 'package:aldurar_alnaqia/common/helpers/logger.dart';

// TODO: make it truely reactive(change after maghrib)
class HijriDateWidget extends ConsumerStatefulWidget {
  const HijriDateWidget({super.key});

  @override
  ConsumerState<HijriDateWidget> createState() => _HijriDateWidgetState();
}

class _HijriDateWidgetState extends ConsumerState<HijriDateWidget> {
  // Timer for scheduling the update at Maghrib.
  Timer? _maghribTimer;
  // The currently displayed Hijri date.
  HijriCalendar? _hijriDate;

  @override
  void initState() {
    super.initState();

    // 1. Set the initial date immediately.
    _updateHijriDate();

    // 2. Listen for any changes in prayer timings (e.g., user changes location).
    //    When they change, reset and reschedule our timer.
    ref.listenManual(prayerProvider, (_, __) {
      _resetAndScheduleUpdate();
    });

    // 3. Listen for changes in the manual Hijri offset.
    ref.listenManual(hijriOffsetProvider, (_, __) => _updateHijriDate());

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
    super.dispose();
  }

  /// Updates the displayed Hijri date based on the offset provider.
  void _updateHijriDate() {
    if (mounted) {
      setState(() {
        _hijriDate = hijriDayWithOffset(ref.read(hijriOffsetProvider));
      });
    }
  }

  /// This is the core logic. It cancels any old timer and schedules a new one
  /// for the next upcoming Maghrib time.
  void _resetAndScheduleUpdate() {
    // Cancel any existing timer before creating a new one.
    _maghribTimer?.cancel();

    // Get today's prayer times from the provider.
    final todaysPrayers = ref.read(prayerProvider).prayerTimings;
      if (todaysPrayers?.maghrib == null) {
        logWarn("HijriDateWidget: Maghrib time not available. Cannot schedule update.");
      return; // Can't schedule if we don't have the time.
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime maghribTime =
        tz.TZDateTime.from(todaysPrayers!.maghrib, tz.local);

    // Check if today's Maghrib has already passed.
    if (maghribTime.isBefore(now)) {
      // If it passed, we need to get *tomorrow's* Maghrib time.
      final tomorrowsPrayers = PrayerTimeings.getPrayersTimings(
        forDate: now.add(const Duration(days: 1)),
      );
        if (tomorrowsPrayers?.maghrib == null) {
          logWarn("HijriDateWidget: Could not calculate tomorrow's Maghrib time.");
        return;
      }
      maghribTime = tz.TZDateTime.from(tomorrowsPrayers!.maghrib, tz.local);
    }

    // Calculate the duration until the next Maghrib.
    final timeUntilMaghrib = maghribTime.difference(now);

      logInfo("HijriDateWidget: Next Hijri day update scheduled in $timeUntilMaghrib");

    // Set a timer that will fire exactly at Maghrib.
    _maghribTimer = Timer(timeUntilMaghrib, () {
        logInfo("HijriDateWidget: Maghrib has arrived! Updating Hijri date.");
      // When the timer fires:
      // 1. Update the date on the screen.
      _updateHijriDate();
      // 2. Schedule the *next* update for the following day's Maghrib.
      _resetAndScheduleUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hijriDate == null) {
      return const SizedBox.shrink();
    }
    return Text(
      '${_hijriDate!.hDay} ${_hijriDate!.longMonthName} ${_hijriDate!.hYear}',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}
