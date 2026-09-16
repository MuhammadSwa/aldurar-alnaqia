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
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/prayer_schedule.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_calculator.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/common/helpers/islamic_date.dart'
    as islamic_date;
import 'package:aldurar_alnaqia/common/helpers/logger.dart';

export 'prayer_calculator.dart'
    show PrayerTimings, arabicPrayerName, islamicWeekdayNow;

/// Immutable snapshot of everything the prayer UI needs.
///
/// Deliberately has NO per-second tick field: the countdown text owns its own
/// 1-second timer locally (see `NextPrayerCountdown`) so this state only
/// changes at event boundaries, settings changes, or midnight. Widgets that
/// `select()` schedule/weekday/next info therefore never rebuild every second
/// and listeners are not woken while the user reads elsewhere.
class PrayerState {
  final PrayerTimes? prayerTimings;

  /// Typed schedule for the current civil date (today + tomorrow Fajr +
  /// Sunnah times), computed once per recalculation. The timetable card
  /// renders from this and must not recalculate times itself.
  final PrayerSchedule? schedule;

  /// The current Islamic day of the week (Monday=1, Sunday=7).
  final int islamicWeekday;
  final (DateTime?, String) nextPrayerInfo;
  final bool isInitialized;

  // ignore: prefer_const_constructors_in_immutables
  PrayerState({
    this.prayerTimings,
    this.schedule,
    int? islamicWeekday,
    this.nextPrayerInfo = (null, ''),
    this.isInitialized = false,
  }) : islamicWeekday = islamicWeekday ?? tz.TZDateTime.now(tz.local).weekday;

  PrayerState copyWith({
    PrayerTimes? prayerTimings,
    PrayerSchedule? schedule,
    int? islamicWeekday,
    (DateTime?, String)? nextPrayerInfo,
    bool? isInitialized,
  }) {
    return PrayerState(
      prayerTimings: prayerTimings ?? this.prayerTimings,
      schedule: schedule ?? this.schedule,
      islamicWeekday: islamicWeekday ?? this.islamicWeekday,
      nextPrayerInfo: nextPrayerInfo ?? this.nextPrayerInfo,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// Owns the day's prayer data and the single boundary timer.
///
/// Heavy work (solar calculation) happens only on init, settings change,
/// event boundary, or midnight; there is intentionally no periodic timer
/// here. A single one-shot [_boundaryTimer] fires at the next
/// prayer/sunrise/midnight boundary (+1s grace) and triggers a full
/// recalculation, which also flips the Islamic weekday at Maghrib.
class PrayerTimingsNotifier extends Notifier<PrayerState> {
  Timer? _boundaryTimer;

  @override
  PrayerState build() {
    ref.onDispose(_dispose);
    _initialize();
    return PrayerState();
  }

  void _dispose() {
    _boundaryTimer?.cancel();
  }

  Future<void> _initialize() async {
    tz.initializeTimeZones();

    await _configureLocationTimezone();
    if (!ref.mounted) return;

    _recalculateAllPrayerData();
    state = state.copyWith(isInitialized: true);
  }

  /// Centralized method to recalculate all prayer data.
  /// Called only when data can fundamentally change: init, settings change,
  /// event boundary, or midnight.
  void _recalculateAllPrayerData() {
    // 1. Calculate and cache today's prayers (legacy object for existing
    //    consumers) and the typed schedule (today + tomorrow Fajr + sunnah).
    // 2. Determine the next prayer and its time.
    // 3. Update the Islamic weekday.
    // 4. Schedule the single one-shot boundary timer.
    final prayers = PrayerTimings.getPrayersTimings();
    final schedule = _currentSchedule();
    state = state.copyWith(prayerTimings: prayers, schedule: schedule);
    _updateNextPrayerInfo();
    _updateIslamicWeekday();
    _scheduleBoundaryTimer();
  }

  /// The typed schedule for the current civil date, or null when settings
  /// are incomplete. Computed at most once per recalculation — never from
  /// a widget build.
  PrayerSchedule? _currentSchedule() {
    final now = tz.TZDateTime.now(tz.local);
    final settings = SharedPreferencesService.loadPrayerSettings();
    // Fall back to tz.local's zone name when no explicit zone is stored yet
    // (fresh installs that picked coordinates but predate zone storage).
    final effective = settings.timezone.isEmpty
        ? settings.copyWith(timezone: tz.local.name)
        : settings;
    return PrayerScheduleCalculator.calculate(settings: effective, date: now);
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

  /// Public refresh for lifecycle edges (e.g. the countdown widget noticing
  /// its target is long past while the boundary timer was suspended).
  /// Cheap: no-ops unless the next event or civil date actually changed.
  void refresh() {
    if (!ref.mounted) return;
    final next = state.nextPrayerInfo.$1;
    final now = tz.TZDateTime.now(tz.local);
    final schedule = state.schedule;
    final dateChanged = schedule == null ||
        now.year != schedule.civilDate.year ||
        now.month != schedule.civilDate.month ||
        now.day != schedule.civilDate.day;
    if (dateChanged || next == null || !next.isAfter(now)) {
      PrayerTimings.invalidateCache();
      _recalculateAllPrayerData();
    }
  }

  Future<void> setPrayerSettings({
    required double lat,
    required double long,
    required String method,
    required String asrCalc,
    String? highLatitudeRule,
    City? city,
    bool? preciseAlerts,
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
      preciseAlerts: preciseAlerts,
    );
    if (!ref.mounted) return;
    _setTimezone(timezone);

    PrayerTimings.invalidateCache();
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

  /// Schedules the SINGLE one-shot timer for the next boundary (next
  /// prayer/sunrise or midnight, whichever comes first, +1s grace).
  /// Battery-friendly: ~7 wakeups/day instead of 86,400.
  void _scheduleBoundaryTimer() {
    _boundaryTimer?.cancel();

    final now = tz.TZDateTime.now(tz.local);
    final candidates = <tz.TZDateTime>[];

    final next = state.nextPrayerInfo.$1;
    if (next != null) candidates.add(tz.TZDateTime.from(next, tz.local));

    // Midnight rollover for the new civil date even when the next prayer is
    // hours away (e.g. after Isha the next event is tomorrow's Fajr, but the
    // timetable must still refresh at midnight).
    candidates.add(
      tz.TZDateTime(tz.local, now.year, now.month, now.day + 1)
          .add(const Duration(seconds: 1)),
    );

    final future = candidates.where((t) => t.isAfter(now)).toList();
    if (future.isEmpty) return;
    future.sort();
    final delay = future.first.difference(now) + const Duration(seconds: 1);

    _boundaryTimer = Timer(delay, () {
      if (ref.mounted) {
        PrayerTimings.invalidateCache();
        _recalculateAllPrayerData();
      }
    });
  }
}

final prayerProvider = NotifierProvider<PrayerTimingsNotifier, PrayerState>(
    PrayerTimingsNotifier.new,);
