import 'package:adhan_dart/adhan_dart.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:aldurar_alnaqia/common/helpers/islamic_date.dart'
    as islamic_date;
import 'package:aldurar_alnaqia/common/helpers/logger.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/prayer_schedule.dart'
    show
        PrayerEventId,
        PrayerMadhabs,
        PrayerScheduleCalculator,
        prayerEventArabicName,
        prayerEventIdFromLibraryName;
import 'package:aldurar_alnaqia/services/shared_prefs.dart';

export 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/prayer_schedule.dart'
    show
        PrayerEventId,
        PrayerSettings,
        PrayerSchedule,
        PrayerEvent,
        prayerEventArabicName,
        prayerConfigVersion;

/// Pure prayer-time calculation. No Riverpod, no widgets.
///
/// [PrayerTimingsNotifier] (in `prayer_timings_controller.dart`) owns timers
/// and UI state; everything that touches `adhan_dart` lives here so it can
/// be unit-tested without a `ProviderContainer`.
class PrayerTimings {
  const PrayerTimings._();

  /// Last today-only calculation, cached for 60s so same-frame callers
  /// (router weekday, yousria cycle, hijri label) share one solar calc
  /// instead of each triggering their own.
  static PrayerTimes? _cachedTimings;
  static String _cachedFingerprint = '';
  static DateTime _cachedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Builds calculation params from explicit values (testable, no prefs).
  ///
  /// Unknown [method] is logged and falls back to `other()` so the UI can
  /// still render *something*; the pure [PrayerScheduleCalculator] used by
  /// the schedule path instead returns null (see its contract).
  static CalculationParameters buildParameters({
    required String method,
    required String asrCalc,
    required double latitude,
    required String highLatitudeRule,
  }) {
    return PrayerScheduleCalculator.buildParametersForParts(
          method: method,
          madhab: asrCalc == 'shafi' ? PrayerMadhabs.shafi : PrayerMadhabs.hanafi,
          latitude: latitude,
          highLatitudeRule: highLatitudeRule,
        ) ??
        CalculationMethodParameters.other();
  }

  /// Reads settings from [SharedPreferencesService] and calculates times
  /// for [forDate] (defaults to now, timezone-aware via `tz.local`).
  /// Returns null when settings are incomplete or calculation fails.
  ///
  /// Today-only requests are cached for 60s (keyed by settings fingerprint +
  /// civil date) so same-frame callers — router weekday, Yousria cycle,
  /// Hijri label — share one solar calculation.
  static PrayerTimes? getPrayersTimings({DateTime? forDate}) {
    final coords = Coordinates(
      SharedPreferencesService.getLatitude(),
      SharedPreferencesService.getLongitude(),
    );
    final method = SharedPreferencesService.getMethod();
    final asrCalc = SharedPreferencesService.getAsrCalculation();

    if (method.isEmpty ||
        asrCalc.isEmpty ||
        (coords.latitude == 0.0 && coords.longitude == 0.0)) {
      return null;
    }

    try {
      final tz.TZDateTime dateForCalculation = forDate != null
          ? tz.TZDateTime.from(forDate, tz.local)
          : tz.TZDateTime.now(tz.local);

      if (forDate == null) {
        final key =
            '$method|$asrCalc|${coords.latitude}|${coords.longitude}|${SharedPreferencesService.getHighLatitudeRule()}|${dateForCalculation.year}-${dateForCalculation.month}-${dateForCalculation.day}';
        if (key == _cachedFingerprint &&
            _cachedTimings != null &&
            DateTime.now().difference(_cachedAt) < const Duration(seconds: 60)) {
          return _cachedTimings;
        }
        final fresh = _compute(coords, method, asrCalc, dateForCalculation);
        if (fresh != null) {
          _cachedTimings = fresh;
          _cachedFingerprint = key;
          _cachedAt = DateTime.now();
        }
        return fresh;
      }

      return _compute(coords, method, asrCalc, dateForCalculation);
    } catch (e) {
      logError('Error initializing prayer times', e);
      return null;
    }
  }

  static PrayerTimes? _compute(
    Coordinates coords,
    String method,
    String asrCalc,
    tz.TZDateTime dateForCalculation,
  ) {
    try {
      final params = buildParameters(
        method: method,
        asrCalc: asrCalc,
        latitude: coords.latitude,
        highLatitudeRule: SharedPreferencesService.getHighLatitudeRule(),
      );

      return PrayerTimes(
        coordinates: coords,
        date: dateForCalculation,
        calculationParameters: params,
        precision: true,
      );
    } catch (e) {
      logError('Error initializing prayer times', e);
      return null;
    }
  }

  /// Clears the today-only cache. Called after settings/timezone changes so
  /// the next read recomputes instead of serving stale times for up to 60s.
  static void invalidateCache() {
    _cachedFingerprint = '';
    _cachedTimings = null;
  }

  /// All prayer times for display (in local timezone).
  static Map<String, tz.TZDateTime>? getAllPrayerTimes() {
    final prayerTimes = getPrayersTimings();
    if (prayerTimes == null) return null;

    try {
      final timezone = tz.local;
      return {
        'fajr': tz.TZDateTime.from(prayerTimes.fajr, timezone),
        'sunrise': tz.TZDateTime.from(prayerTimes.sunrise, timezone),
        'dhuhr': tz.TZDateTime.from(prayerTimes.dhuhr, timezone),
        'asr': tz.TZDateTime.from(prayerTimes.asr, timezone),
        'maghrib': tz.TZDateTime.from(prayerTimes.maghrib, timezone),
        'isha': tz.TZDateTime.from(prayerTimes.isha, timezone),
      };
    } catch (e) {
      logError('Error getting prayer times', e);
      return null;
    }
  }
}

/// Maps English prayer names from the library to Arabic.
/// Note: 'fajrAfter' (tomorrow's Fajr) is normalized to 'fajr' by the
/// caller before lookup, so no separate entry is needed.
/// Single table lives in [prayerEventArabicName]; this stays for callers
/// that still pass raw library strings.
String arabicPrayerName(String englishName) {
  final id = prayerEventIdFromLibraryName(englishName);
  return prayerEventArabicName(id ?? PrayerEventId.fajr);
}

/// The current Islamic weekday (after Maghrib the next day begins),
/// computed without needing a running notifier — safe for routing.
int islamicWeekdayNow() {
  final now = tz.TZDateTime.now(tz.local);
  final maghrib = PrayerTimings.getPrayersTimings()?.maghrib;
  if (maghrib == null) return now.weekday;
  final maghribTime = tz.TZDateTime.from(maghrib, tz.local);
  return islamic_date.islamicWeekday(now: now, maghrib: maghribTime);
}
