import 'package:adhan_dart/adhan_dart.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:aldurar_alnaqia/common/helpers/islamic_date.dart'
    as islamic_date;
import 'package:aldurar_alnaqia/common/helpers/logger.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';

/// Pure prayer-time calculation. No Riverpod, no widgets.
///
/// [PrayerTimingsNotifier] (in `prayer_timings_controller.dart`) owns timers
/// and UI state; everything that touches `adhan_dart` lives here so it can
/// be unit-tested without a `ProviderContainer`.
class PrayerTimeings {
  const PrayerTimeings._();

  /// Factories per stored method key. Replaces the 12-branch switch.
  static final Map<String, CalculationParameters Function()> _methodFactories =
      {
    'egyptian': CalculationMethodParameters.egyptian,
    'karachi': CalculationMethodParameters.karachi,
    'muslim_world_league': CalculationMethodParameters.muslimWorldLeague,
    'dubai': CalculationMethodParameters.dubai,
    'qatar': CalculationMethodParameters.qatar,
    'kuwait': CalculationMethodParameters.kuwait,
    'turkey': CalculationMethodParameters.turkiye,
    'tehran': CalculationMethodParameters.tehran,
    'singapore': CalculationMethodParameters.singapore,
    'umm_al_qura': CalculationMethodParameters.ummAlQura,
    'north_america': CalculationMethodParameters.northAmerica,
    'moon_sighting_committee':
        CalculationMethodParameters.moonsightingCommittee,
  };

  static final Map<String, HighLatitudeRule> _highLatitudeRules = {
    'middle_of_night': HighLatitudeRule.middleOfTheNight,
    'seventh_of_night': HighLatitudeRule.seventhOfTheNight,
    'twilight_angle': HighLatitudeRule.twilightAngle,
  };

  /// Builds calculation params from explicit values (testable, no prefs).
  static CalculationParameters buildParameters({
    required String method,
    required String asrCalc,
    required double latitude,
    required String highLatitudeRule,
  }) {
    final factory = _methodFactories[method];
    final params =
        factory != null ? factory() : CalculationMethodParameters.other();

    params.madhab = asrCalc == 'shafi' ? Madhab.shafi : Madhab.hanafi;

    if (latitude.abs() > 48.0) {
      params.highLatitudeRule = _highLatitudeRules[highLatitudeRule] ??
          HighLatitudeRule.middleOfTheNight;
    }
    return params;
  }

  /// Reads settings from [SharedPreferencesService] and calculates times
  /// for [forDate] (defaults to now, timezone-aware via `tz.local`).
  /// Returns null when settings are incomplete or calculation fails.
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
const Map<String, String> _arabicPrayerNames = {
  'fajr': 'الفجر',
  'fajrafter': 'الفجر',
  'sunrise': 'الشروق',
  'dhuhr': 'الظهر',
  'asr': 'العصر',
  'maghrib': 'المغرب',
  'isha': 'العشاء',
};

String arabicPrayerName(String englishName) {
  return _arabicPrayerNames[englishName.toLowerCase()] ?? 'الفجر';
}

/// The current Islamic weekday (after Maghrib the next day begins),
/// computed without needing a running notifier — safe for routing.
int islamicWeekdayNow() {
  final now = tz.TZDateTime.now(tz.local);
  final maghrib = PrayerTimeings.getPrayersTimings()?.maghrib;
  if (maghrib == null) return now.weekday;
  final maghribTime = tz.TZDateTime.from(maghrib, tz.local);
  return islamic_date.islamicWeekday(now: now, maghrib: maghribTime);
}
