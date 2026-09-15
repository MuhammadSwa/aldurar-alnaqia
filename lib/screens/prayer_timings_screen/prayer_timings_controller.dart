import 'dart:async';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
// GeoNames supplies IANA timezone IDs for cities worldwide. The full database
// is required because the smaller default database omits some valid zones.
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/city_directory.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/location_timezone.dart';
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
  }) : islamicWeekday = islamicWeekday ?? tz.TZDateTime.now(tz.local).weekday;

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

    await _configureLocationTimezone();
    if (!ref.mounted) return;

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
      nextPrayerInfo: (
        localNextPrayerTime,
        arabicPrayerName(nextPrayerNameString)
      ),
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

  Future<void> setPrayerSettings({
    required double lat,
    required double long,
    required String method,
    required String asrCalc,
    String? highLatitudeRule,
    City? city,
  }) async {
    final timezone = await _resolveTimezone(lat, long, city);
    if (timezone == null) {
      logWarn('Could not resolve timezone for $lat, $long.');
      return;
    }
    if (!ref.mounted) return;
    await SharedPreferencesService.savePrayerSettings(
      latitude: lat,
      longitude: long,
      method: method,
      asrCalculation: asrCalc,
      timezone: timezone,
      highLatitudeRule: highLatitudeRule,
      city: city,
    );
    if (!ref.mounted) return;
    _setTimezone(timezone);

    _recalculateAllPrayerData();
  }

  Future<void> _configureLocationTimezone() async {
    final storedTimezone = SharedPreferencesService.getTimezone();
    if (_setTimezone(storedTimezone)) return;

    final latitude = SharedPreferencesService.getLatitude();
    final longitude = SharedPreferencesService.getLongitude();
    // (0, 0) is the legacy "no location selected" sentinel. Do not invent a
    // timezone for a user who has not selected a location yet.
    if (latitude == 0.0 && longitude == 0.0) return;
    final timezone = await _resolveTimezone(
      latitude,
      longitude,
      SharedPreferencesService.getCity(),
    );
    if (timezone == null || !ref.mounted) return;

    await SharedPreferencesService.savePrayerSettings(
      latitude: latitude,
      longitude: longitude,
      method: SharedPreferencesService.getMethod(),
      asrCalculation: SharedPreferencesService.getAsrCalculation(),
      timezone: timezone,
      highLatitudeRule: SharedPreferencesService.getHighLatitudeRule(),
      city: SharedPreferencesService.getCity(),
    );
    _setTimezone(timezone);
  }

  Future<String?> _resolveTimezone(
    double latitude,
    double longitude,
    City? selectedCity,
  ) async {
    final directory = await ref.read(cityDirectoryProvider.future);
    return LocationTimezone.resolve(
      latitude: latitude,
      longitude: longitude,
      cities: directory.cities,
      selectedCity: selectedCity,
    );
  }

  bool _setTimezone(String timezone) {
    if (timezone.isEmpty) return false;
    try {
      tz.setLocalLocation(tz.getLocation(timezone));
      logInfo('Prayer timezone set to: ${tz.local.name}');
      return true;
    } catch (error) {
      logWarn('Invalid prayer timezone "$timezone": $error');
      return false;
    }
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

final prayerProvider = NotifierProvider<PrayerTimingsNotifier, PrayerState>(
    PrayerTimingsNotifier.new);
