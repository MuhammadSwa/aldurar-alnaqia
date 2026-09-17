import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
// GeoNames supplies IANA timezone IDs for cities worldwide. The full database
// is required because the smaller default database omits some valid zones.
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/city_directory.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/location_timezone.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/prayer_schedule.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/common/helpers/islamic_date.dart'
    as islamic_date;
import 'package:aldurar_alnaqia/common/helpers/logger.dart';

/// The current Islamic weekday (Monday=1, Sunday=7; the day flips at Maghrib).
/// Standalone (no provider needed) for routing and list badges.
int islamicWeekdayNow() {
  final schedule = todayPrayerSchedule();
  if (schedule == null) return DateTime.now().weekday;
  final now = tz.TZDateTime.now(schedule.civilDate.location);
  return islamic_date.islamicWeekday(now: now, maghrib: schedule.maghrib);
}

/// Today's schedule from stored settings, or null when unconfigured.
/// Single shared entry point for non-provider callers (routing, Yousria).
/// Never throws: returns null when prefs/tz are unavailable (e.g. tests).
PrayerSchedule? todayPrayerSchedule() {
  final settings = SharedPreferencesService.loadPrayerSettings();
  final zone = settings.timezone.isEmpty ? _localZoneName() : settings.timezone;
  if (zone == null) return null;
  try {
    final location = tz.getLocation(zone);
    return PrayerScheduleCalculator.calculate(
      settings: settings.copyWith(timezone: zone),
      date: tz.TZDateTime.now(location),
    );
  } catch (_) {
    return null;
  }
}

/// Global local zone without throwing when the tz database is not
/// initialized yet (unit tests, very early startup).
String? _localZoneName() {
  try {
    return tz.local.name;
  } catch (_) {
    return null;
  }
}

/// Pure decision helper (unit-testable): true when the cached next-prayer
/// no longer matches what [schedule] says is next at [now].
///
/// Catches manual clock changes the one-shot boundary timer can't see: after
/// a backward jump (e.g. 2:17pm → 2am) the cached next (Asr) is still in the
/// future, so a naive "is it past?" guard no-ops — but the true next at 2am
/// is Fajr. Re-evaluating `nextEventAt` is O(6) and allocation-free enough
/// to run on every countdown tick; the expensive solar recalculation only
/// runs when this returns true.
@visibleForTesting
bool nextPrayerIsStale({
  required PrayerSchedule schedule,
  required DateTime? cachedNext,
  required String cachedName,
  required DateTime now,
}) {
  if (cachedNext == null) return true;
  if (!cachedNext.isAfter(now)) return true;
  final live = schedule.nextEventAt(
    tz.TZDateTime.from(now, schedule.civilDate.location),
  );
  return live.time.millisecondsSinceEpoch !=
          cachedNext.millisecondsSinceEpoch ||
      live.arabicName != cachedName;
}

/// Immutable snapshot of everything the prayer UI needs.
///
/// Deliberately has NO per-second tick field: the countdown text owns its own
/// 1-second timer locally (see `NextPrayerCountdown`) so this state only
/// changes at event boundaries, settings changes, or midnight. Widgets that
/// `select()` schedule/weekday/next info therefore never rebuild every second
/// and listeners are not woken while the user reads elsewhere.
class PrayerState {
  final PrayerSchedule? schedule;
  final int islamicWeekday;
  final (DateTime?, String) nextPrayerInfo;
  final bool isInitialized;

  /// Display label for the configured location ('القاهرة، مصر'), resolved
  /// and persisted at save time (city pick → exact label; GPS → nearest
  /// city within 50 km; remote area → formatted coordinates). Empty when
  /// unconfigured. No directory load is needed to render it.
  final String cityLabel;

  // ignore: prefer_const_constructors_in_immutables
  PrayerState({
    this.schedule,
    int? islamicWeekday,
    this.nextPrayerInfo = (null, ''),
    this.isInitialized = false,
    this.cityLabel = '',
  }) : islamicWeekday = islamicWeekday ?? tz.TZDateTime.now(tz.local).weekday;

  PrayerState copyWith({
    PrayerSchedule? schedule,
    int? islamicWeekday,
    (DateTime?, String)? nextPrayerInfo,
    bool? isInitialized,
    String? cityLabel,
  }) {
    return PrayerState(
      schedule: schedule ?? this.schedule,
      islamicWeekday: islamicWeekday ?? this.islamicWeekday,
      nextPrayerInfo: nextPrayerInfo ?? this.nextPrayerInfo,
      isInitialized: isInitialized ?? this.isInitialized,
      cityLabel: cityLabel ?? this.cityLabel,
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
    final schedule = todayPrayerSchedule();
    state = state.copyWith(schedule: schedule, cityLabel: _locationLabel());
    _updateNextPrayerInfo();
    _updateIslamicWeekday();
    _scheduleBoundaryTimer();
  }

  /// Persisted label, falling back to the stored city's own name for
  /// installs saved before labels existed (no country suffix).
  String _locationLabel() {
    final label = SharedPreferencesService.getPrayerCityLabel();
    if (label.isNotEmpty) return label;
    return SharedPreferencesService.getCity()?.displayName ?? '';
  }

  void _updateNextPrayerInfo() {
    final schedule = state.schedule;
    if (schedule == null) {
      state = state.copyWith(nextPrayerInfo: (null, ''));
      return;
    }
    final next =
        schedule.nextEventAt(tz.TZDateTime.now(schedule.civilDate.location));
    state = state.copyWith(
      nextPrayerInfo: (next.time, next.arabicName),
    );
  }

  /// Public refresh for lifecycle edges and clock jumps (e.g. the countdown
  /// widget noticing its target is long past while the boundary timer was
  /// suspended, or a manual system-clock change while the app was open).
  /// Cheap: re-evaluates the next event from the cached schedule (no solar
  /// math) and no-ops unless the next event or civil date actually changed.
  /// Callers may invoke it on every countdown tick.
  void refresh() {
    if (!ref.mounted) return;
    final schedule = state.schedule;
    // Unconfigured: nothing cached to sync; schedule appears via init or
    // settings saves, which rebuild listeners on their own.
    if (schedule == null) return;
    final now = tz.TZDateTime.now(schedule.civilDate.location);
    final civil = schedule.civilDate;
    final dateChanged =
        now.year != civil.year || now.month != civil.month || now.day != civil.day;
    if (dateChanged ||
        nextPrayerIsStale(
          schedule: schedule,
          cachedNext: state.nextPrayerInfo.$1,
          cachedName: state.nextPrayerInfo.$2,
          now: now,
        )) {
      _recalculateAllPrayerData();
    }
  }

  /// Force path for app-resume: the system clock (or date) may have changed
  /// while the UI was backgrounded and timers suspended. One solar
  /// calculation per resume is negligible and guarantees fresh state.
  /// The native 30-day tables are absolute instants and self-heal, so no
  /// native rewrite is needed here.
  void handleResume() {
    if (!ref.mounted) return;
    if (state.schedule == null) return;
    _recalculateAllPrayerData();
  }

  Future<void> setPrayerSettings({
    required double lat,
    required double long,
    required String method,
    required String asrCalc,
    String? highLatitudeRule,
    City? city,
  }) async {
    final directory = await ref.read(cityDirectoryProvider.future);

    // Display label only. GPS (city == null) → nearest city within 50 km,
    // else coordinates. Prayer math and timezone resolution keep using the
    // exact coordinates; cityInfo semantics are unchanged.
    final labelCity = city ??
        LocationTimezone.nearestCity(
          latitude: lat,
          longitude: long,
          cities: directory.cities,
        );
    final cityLabel = labelCity != null
        ? directory.cityLabel(labelCity)
        : '${lat.toStringAsFixed(2)}°، ${long.toStringAsFixed(2)}°';

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
      cityLabel: cityLabel,
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
    // (0, 0) means no location selected yet. Do not invent a timezone.
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
    final maghrib = state.schedule?.maghrib;

    if (maghrib == null) {
      state = state.copyWith(islamicWeekday: now.weekday); // Fallback
      return;
    }

    final effectiveDate =
        islamic_date.islamicEffectiveDate(now: now, maghrib: maghrib);
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
        _recalculateAllPrayerData();
      }
    });
  }
}

final prayerProvider = NotifierProvider<PrayerTimingsNotifier, PrayerState>(
  PrayerTimingsNotifier.new,
);
