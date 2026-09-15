import 'dart:async';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_calculator.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/common/helpers/islamic_date.dart'
    as islamic_date;
import 'package:aldurar_alnaqia/common/helpers/logger.dart';

export 'prayer_calculator.dart'
    show PrayerTimeings, arabicPrayerName, islamicWeekdayNow;

/// Immutable snapshot of everything the prayer UI needs.
class PrayerState {
  final PrayerTimes? prayerTimings;

  /// The current Islamic day of the week (Monday=1, Sunday=7).
  final int islamicWeekday;
  final (DateTime?, String) nextPrayerInfo;
  final Duration timeLeft;
  final bool isInitialized;

  // ignore: prefer_const_constructors_in_immutables
  PrayerState({
    this.prayerTimings,
    int? islamicWeekday,
    this.nextPrayerInfo = (null, ''),
    this.timeLeft = Duration.zero,
    this.isInitialized = false,
  }) : islamicWeekday = islamicWeekday ?? DateTime.now().weekday;

  PrayerState copyWith({
    PrayerTimes? prayerTimings,
    int? islamicWeekday,
    (DateTime?, String)? nextPrayerInfo,
    Duration? timeLeft,
    bool? isInitialized,
  }) {
    return PrayerState(
      prayerTimings: prayerTimings ?? this.prayerTimings,
      islamicWeekday: islamicWeekday ?? this.islamicWeekday,
      nextPrayerInfo: nextPrayerInfo ?? this.nextPrayerInfo,
      timeLeft: timeLeft ?? this.timeLeft,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// Owns the day's prayer times and drives the countdown.
/// Heavy work (solar calculation) happens only on init, settings change or
/// day change; the per-second tick only computes a time difference.
class PrayerTimingsNotifier extends Notifier<PrayerState> {
  Timer? _countdownTimer;
  Timer? _dayChangeTimer;

  @override
  PrayerState build() {
    ref.onDispose(_dispose);
    _initialize();
    return PrayerState();
  }

  void _dispose() {
    _countdownTimer?.cancel();
    _dayChangeTimer?.cancel();
  }

  Future<void> _initialize() async {
    tz.initializeTimeZones();

    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      final String localTimezoneName = localTimezone.identifier;
      if (!ref.mounted) return;
      tz.setLocalLocation(tz.getLocation(localTimezoneName));
      SharedPreferencesService.setTimezone(localTimezoneName);
      logInfo("Device timezone set to: ${tz.local.name}");
    } catch (e) {
      logWarn("Failed to get or set local timezone: $e");
      // Fallback to stored timezone
      final String storedTimezone = SharedPreferencesService.getTimezone();
      if (storedTimezone.isNotEmpty) {
        try {
          tz.setLocalLocation(tz.getLocation(storedTimezone));
          logInfo("Using stored timezone: ${tz.local.name}");
        } catch (tzError) {
          logWarn(
              "Failed to load stored timezone '$storedTimezone': $tzError.");
        }
      }
    }

    _recalculateAllPrayerData();
    state = state.copyWith(isInitialized: true);
  }

  /// Centralized method to recalculate all prayer data.
  /// Called only when data can fundamentally change.
  void _recalculateAllPrayerData() {
    // 1. Calculate and cache prayer times for the current day.
    // 2. Determine the next prayer and its time.
    // 3. Schedule the timer for the Islamic day change (at Maghrib).
    // 4. Start/restart the 1-second countdown timer.
    final prayers = PrayerTimeings.getPrayersTimings();
    state = state.copyWith(prayerTimings: prayers);
    _updateNextPrayerInfo();
    _updateAndScheduleDayChange();
    _startCountdownTimer();
  }

  void _updateNextPrayerInfo() {
    final prayers = state.prayerTimings;
    if (prayers == null) {
      state = state.copyWith(nextPrayerInfo: (null, ''));
      return;
    }
    String nextPrayerNameString = prayers.nextPrayer().name;
    DateTime nextPrayerDateTime = prayers.timeForPrayer(prayers.nextPrayer());

    // The library returns 'fajrAfter' for tomorrow's Fajr. We use that.
    if (nextPrayerNameString == 'fajrAfter') {
      nextPrayerDateTime = prayers.fajrAfter;
      nextPrayerNameString = 'fajr'; // Standardize the name
    }

    final tz.TZDateTime localNextPrayerTime =
        tz.TZDateTime.from(nextPrayerDateTime, tz.local);
    state = state.copyWith(
      nextPrayerInfo: (localNextPrayerTime, arabicPrayerName(nextPrayerNameString)),
    );
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!ref.mounted) {
        timer.cancel();
        return;
      }
      final nextPrayerTime = state.nextPrayerInfo.$1;

      if (nextPrayerTime == null) return;

      final now = tz.TZDateTime.now(tz.local);
      var newTimeLeft = nextPrayerTime.difference(now);

      // If time is up, it's time to recalculate the *next* prayer.
      if (newTimeLeft.isNegative) {
        _updateNextPrayerInfo();
        newTimeLeft = Duration.zero;
      }
      state = state.copyWith(timeLeft: newTimeLeft);
    });
  }

  void setPrayerSettings({
    required double lat,
    required double long,
    required String method,
    required String asrCalc,
    String? highLatitudeRule,
    City? city,
  }) {
    SharedPreferencesService.setLatitude(lat);
    SharedPreferencesService.setLongitude(long);
    SharedPreferencesService.setMethod(method);
    SharedPreferencesService.setAsrCalculation(asrCalc);
    SharedPreferencesService.setCity(city);
    if (highLatitudeRule != null) {
      SharedPreferencesService.setHighLatitudeRule(highLatitudeRule);
    }

    _recalculateAllPrayerData();
  }

  void _updateIslamicWeekday() {
    final now = tz.TZDateTime.now(tz.local);
    final prayers = state.prayerTimings;

    if (prayers == null) {
      state = state.copyWith(islamicWeekday: now.weekday); // Fallback
      return;
    }

    final maghribTime = tz.TZDateTime.from(prayers.maghrib, tz.local);
    final effectiveDate =
        islamic_date.islamicEffectiveDate(now: now, maghrib: maghribTime);
    state = state.copyWith(islamicWeekday: effectiveDate.weekday);
  }

  /// Schedules a SINGLE timer to fire at the next Maghrib (battery friendly).
  void _updateAndScheduleDayChange() {
    _updateIslamicWeekday();
    _dayChangeTimer?.cancel();

    final prayers = state.prayerTimings;
    if (prayers == null) return;

    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime nextMaghrib = tz.TZDateTime.from(prayers.maghrib, tz.local);

    if (now.isAfter(nextMaghrib)) {
      final tomorrowsPrayers = PrayerTimeings.getPrayersTimings(
          forDate: now.add(const Duration(days: 1)));
      if (tomorrowsPrayers != null) {
        nextMaghrib = tz.TZDateTime.from(tomorrowsPrayers.maghrib, tz.local);
      } else {
        return;
      }
    }

    final timeUntilNextMaghrib = nextMaghrib.difference(now);

    _dayChangeTimer = Timer(timeUntilNextMaghrib, () {
      // Once Maghrib hits, recalculate everything for the new Islamic day.
      if (ref.mounted) {
        _recalculateAllPrayerData();
      }
    });
  }
}

final prayerProvider =
    NotifierProvider<PrayerTimingsNotifier, PrayerState>(
        PrayerTimingsNotifier.new);
