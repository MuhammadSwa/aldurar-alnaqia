// models/prayer_schedule.dart
//
// Single Flutter prayer domain model (contract v1).
//
// This is the sole source of truth for prayer calculation inputs/outputs on
// the Dart side. The pure [PrayerScheduleCalculator] takes an explicit
// [PrayerSettings] + date and never touches SharedPreferences or the global
// `tz.local`, so it is unit-testable with a fixed date/timezone.
//
// Cross-platform contract (must match Kotlin `PrayerNotificationService`):
//   - stable method IDs: egyptian, karachi, muslim_world_league, dubai, qatar,
//     kuwait, turkey, tehran, singapore, umm_al_qura, north_america,
//     moon_sighting_committee
//   - madhab IDs: shafi | hanafi
//   - high-latitude IDs: middle_of_night | seventh_of_night | twilight_angle
//   - timezone: required IANA ID (e.g. Africa/Cairo); empty is invalid
//   - event IDs: [PrayerEventId] (never Arabic strings) in business logic;
//     Arabic labels only at render time via [prayerEventArabicName]
//   - timestamps cross the platform boundary as epoch milliseconds
//
// Known divergence (documented, not silent): adhan2 0.0.5 on Kotlin has no
// TEHRAN method and no maghribAngle field, so Kotlin approximates Tehran as
// OTHER(fajrAngle 17.7, ishaAngle 14.0) while Dart uses the full Tehran
// parameters (fajr 17.7, isha 14, maghribAngle 4.5). Expect Maghrib to differ
// by a few minutes for `tehran` until adhan2 is upgraded.

import 'package:adhan_dart/adhan_dart.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:aldurar_alnaqia/common/helpers/logger.dart';

/// Version of the cross-platform prayer-settings contract. Persisted with the
/// native config so a future contract change can migrate instead of silently
/// misreading old JSON.
const int prayerConfigVersion = 1;

/// Stable event identifiers. `sunrise.isPrayer == false` so it can never
/// accidentally trigger an adhan/arrival alert.
enum PrayerEventId { fajr, sunrise, dhuhr, asr, maghrib, isha }

/// Arabic display names. Presentation only — never use these as map keys or
/// identifiers in business logic.
String prayerEventArabicName(PrayerEventId id) => switch (id) {
      PrayerEventId.fajr => 'الفجر',
      PrayerEventId.sunrise => 'الشروق',
      PrayerEventId.dhuhr => 'الظهر',
      PrayerEventId.asr => 'العصر',
      PrayerEventId.maghrib => 'المغرب',
      PrayerEventId.isha => 'العشاء',
    };

/// Parses the stable ID back from the English prayer-name strings returned
/// by `adhan_dart` (`fajr`, `sunrise`, …, plus `fajrAfter` for tomorrow's
/// Fajr). Returns null for unknown names instead of guessing.
PrayerEventId? prayerEventIdFromLibraryName(String name) =>
    switch (name.toLowerCase()) {
      'fajr' || 'fajrafter' => PrayerEventId.fajr,
      'sunrise' => PrayerEventId.sunrise,
      'dhuhr' => PrayerEventId.dhuhr,
      'asr' => PrayerEventId.asr,
      'maghrib' => PrayerEventId.maghrib,
      'isha' => PrayerEventId.isha,
      _ => null,
    };

/// Canonical calculation-method keys. Single Dart-side source; the dropdown
/// list in `calculation_method_info.dart` and the Kotlin `when` must use
/// exactly these strings.
abstract final class PrayerMethods {
  static const String egyptian = 'egyptian';
  static const String karachi = 'karachi';
  static const String muslimWorldLeague = 'muslim_world_league';
  static const String dubai = 'dubai';
  static const String qatar = 'qatar';
  static const String kuwait = 'kuwait';
  static const String turkey = 'turkey';
  static const String tehran = 'tehran';
  static const String singapore = 'singapore';
  static const String ummAlQura = 'umm_al_qura';
  static const String northAmerica = 'north_america';
  static const String moonSightingCommittee = 'moon_sighting_committee';

  static const Set<String> all = {
    egyptian,
    karachi,
    muslimWorldLeague,
    dubai,
    qatar,
    kuwait,
    turkey,
    tehran,
    singapore,
    ummAlQura,
    northAmerica,
    moonSightingCommittee,
  };

  static bool isValid(String key) => all.contains(key);
}

/// Canonical madhab IDs.
abstract final class PrayerMadhabs {
  static const String shafi = 'shafi';
  static const String hanafi = 'hanafi';

  static bool isValid(String value) => value == shafi || value == hanafi;
}

/// Canonical high-latitude-rule IDs.
abstract final class PrayerHighLatitudeRules {
  static const String middleOfNight = 'middle_of_night';
  static const String seventhOfNight = 'seventh_of_night';
  static const String twilightAngle = 'twilight_angle';

  static bool isValid(String value) =>
      value == middleOfNight ||
      value == seventhOfNight ||
      value == twilightAngle;
}

/// Typed prayer settings. Replaces the loose bag of preference strings.
/// Invalid values are rejected visibly ([validate] returns the reason) —
/// callers must not silently swap in a different method.
class PrayerSettings {
  final double latitude;
  final double longitude;
  final String timezone;
  final String method;
  final String madhab;
  final String highLatitudeRule;
  final int hijriOffset;

  const PrayerSettings({
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.method,
    required this.madhab,
    required this.highLatitudeRule,
    this.hijriOffset = 0,
  });

  static const PrayerSettings defaults = PrayerSettings(
    latitude: 0,
    longitude: 0,
    timezone: '',
    method: PrayerMethods.egyptian,
    madhab: PrayerMadhabs.shafi,
    highLatitudeRule: PrayerHighLatitudeRules.middleOfNight,
  );

  /// Null when valid, otherwise a human-readable reason. Never throws.
  String? validate() {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return 'invalid coordinates ($latitude, $longitude)';
    }
    // (0, 0) is the "no location selected" sentinel.
    if (latitude == 0.0 && longitude == 0.0) return 'no location selected';
    if (timezone.isEmpty) return 'missing timezone';
    try {
      tz.getLocation(timezone);
    } catch (_) {
      return 'unknown timezone "$timezone"';
    }
    if (!PrayerMethods.isValid(method)) return 'unknown method "$method"';
    if (!PrayerMadhabs.isValid(madhab)) return 'unknown madhab "$madhab"';
    if (!PrayerHighLatitudeRules.isValid(highLatitudeRule)) {
      return 'unknown high-latitude rule "$highLatitudeRule"';
    }
    return null;
  }

  bool get isValid => validate() == null;

  /// Stable fingerprint for change detection / debugging.
  String get fingerprint =>
      '$latitude,$longitude|$timezone|$method|$madhab|$highLatitudeRule|$hijriOffset|v$prayerConfigVersion';

  /// Native bridge serialization (epoch-ms-free: settings only, no times).
  /// Single writer: `SharedPreferencesService.savePrayerSettings`.
  Map<String, Object?> toNativeMap() => {
        'version': prayerConfigVersion,
        'lat': latitude,
        'lng': longitude,
        'method': method,
        'asrCalculation': madhab,
        'highLatitudeRule': highLatitudeRule,
        'timezone': timezone,
        'hijriOffset': hijriOffset,
      };

  /// Reads the native map defensively: unknown/missing method IDs fall back
  /// to the default *visibly* (caller should log [validate]).
  factory PrayerSettings.fromNativeMap(Map<String, Object?> map) {
    double toDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    return PrayerSettings(
      latitude: toDouble(map['lat']),
      longitude: toDouble(map['lng']),
      timezone: '${map['timezone'] ?? ''}',
      method: '${map['method'] ?? PrayerMethods.egyptian}',
      madhab: '${map['asrCalculation'] ?? PrayerMadhabs.shafi}',
      highLatitudeRule:
          '${map['highLatitudeRule'] ?? PrayerHighLatitudeRules.middleOfNight}',
      hijriOffset: switch (map['hijriOffset']) {
        final int v => v,
        final double v => v.toInt(),
        _ => int.tryParse('${map['hijriOffset']}') ?? 0,
      },
    );
  }

  PrayerSettings copyWith({
    double? latitude,
    double? longitude,
    String? timezone,
    String? method,
    String? madhab,
    String? highLatitudeRule,
    int? hijriOffset,
  }) =>
      PrayerSettings(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        timezone: timezone ?? this.timezone,
        method: method ?? this.method,
        madhab: madhab ?? this.madhab,
        highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
        hijriOffset: hijriOffset ?? this.hijriOffset,
      );

  @override
  String toString() => 'PrayerSettings($fingerprint)';
}

/// One prayer event on a civil date.
class PrayerEvent {
  final PrayerEventId id;
  final tz.TZDateTime time;

  const PrayerEvent({required this.id, required this.time});

  /// Sunrise advances the UI's next-event state but must never fire an
  /// arrival/adhan alert.
  bool get isPrayer => id != PrayerEventId.sunrise;

  String get arabicName => prayerEventArabicName(id);
}

/// Derived Sunnah times (Maghrib-anchored night + Duha).
class SunnahTimes {
  final tz.TZDateTime middleOfNight;
  final tz.TZDateTime lastThirdOfNight;
  final tz.TZDateTime duha;

  const SunnahTimes({
    required this.middleOfNight,
    required this.lastThirdOfNight,
    required this.duha,
  });
}

/// All prayer data for one civil date, computed once per day.
///
/// The UI must render from this and never recalculate times itself.
class PrayerSchedule {
  final PrayerSettings settings;
  final tz.TZDateTime civilDate;
  final Map<PrayerEventId, PrayerEvent> events;
  final tz.TZDateTime tomorrowFajr;
  final SunnahTimes? sunnah;

  const PrayerSchedule({
    required this.settings,
    required this.civilDate,
    required this.events,
    required this.tomorrowFajr,
    this.sunnah,
  });

  tz.TZDateTime get maghrib => events[PrayerEventId.maghrib]!.time;

  List<PrayerEvent> get ordered => PrayerEventId.values.map((id) => events[id]!).toList();

  /// Next event strictly after [now]; after Isha this is tomorrow's Fajr.
  PrayerEvent nextEventAt(tz.TZDateTime now) {
    for (final event in ordered) {
      if (event.time.isAfter(now)) return event;
    }
    return PrayerEvent(id: PrayerEventId.fajr, time: tomorrowFajr);
  }
}

/// Pure calculator. No prefs, no `tz.local` — the zone comes from settings.
abstract final class PrayerScheduleCalculator {
  static final Map<String, CalculationParameters Function()> _methodFactories =
      {
    PrayerMethods.egyptian: CalculationMethodParameters.egyptian,
    PrayerMethods.karachi: CalculationMethodParameters.karachi,
    PrayerMethods.muslimWorldLeague:
        CalculationMethodParameters.muslimWorldLeague,
    PrayerMethods.dubai: CalculationMethodParameters.dubai,
    PrayerMethods.qatar: CalculationMethodParameters.qatar,
    PrayerMethods.kuwait: CalculationMethodParameters.kuwait,
    PrayerMethods.turkey: CalculationMethodParameters.turkiye,
    PrayerMethods.tehran: CalculationMethodParameters.tehran,
    PrayerMethods.singapore: CalculationMethodParameters.singapore,
    PrayerMethods.ummAlQura: CalculationMethodParameters.ummAlQura,
    PrayerMethods.northAmerica: CalculationMethodParameters.northAmerica,
    PrayerMethods.moonSightingCommittee:
        CalculationMethodParameters.moonsightingCommittee,
  };

  static final Map<String, HighLatitudeRule> _highLatitudeRules = {
    PrayerHighLatitudeRules.middleOfNight: HighLatitudeRule.middleOfTheNight,
    PrayerHighLatitudeRules.seventhOfNight: HighLatitudeRule.seventhOfTheNight,
    PrayerHighLatitudeRules.twilightAngle: HighLatitudeRule.twilightAngle,
  };

  /// Builds calculation params. Returns null for unknown method/madhab
  /// instead of silently substituting a different method.
  static CalculationParameters? buildParameters(PrayerSettings settings) {
    final factory = _methodFactories[settings.method];
    if (factory == null) {
      logWarn('Unknown prayer method "${settings.method}": refusing to guess.');
      return null;
    }
    if (!PrayerMadhabs.isValid(settings.madhab)) {
      logWarn('Unknown madhab "${settings.madhab}": refusing to guess.');
      return null;
    }
    final params = factory();
    params.madhab =
        settings.madhab == PrayerMadhabs.shafi ? Madhab.shafi : Madhab.hanafi;
    if (settings.latitude.abs() > 48.0) {
      final rule = _highLatitudeRules[settings.highLatitudeRule];
      if (rule == null) {
        logWarn(
            'Unknown high-latitude rule "${settings.highLatitudeRule}": using middle_of_night.',);
      }
      params.highLatitudeRule = rule ?? HighLatitudeRule.middleOfTheNight;
    }
    return params;
  }

  /// Calculates [date]'s schedule in [settings.timezone]. Returns null when
  /// settings are invalid or the zone/calculation fails (logged, visible to
  /// the caller — never a silent wrong-method schedule).
  static PrayerSchedule? calculate({
    required PrayerSettings settings,
    required DateTime date,
  }) {
    final reason = settings.validate();
    if (reason != null) {
      logWarn('Skipping prayer calculation: $reason.');
      return null;
    }
    final params = buildParameters(settings);
    if (params == null) return null;
    try {
      final location = tz.getLocation(settings.timezone);
      final coords = Coordinates(settings.latitude, settings.longitude);
      final civilDay = tz.TZDateTime(location, date.year, date.month, date.day);
      final today = PrayerTimes(
        coordinates: coords,
        date: tz.TZDateTime(location, date.year, date.month, date.day, 12),
        calculationParameters: params,
        precision: true,
      );
      final tomorrowDate = civilDay.add(const Duration(days: 1));
      final tomorrow = PrayerTimes(
        coordinates: coords,
        date: tz.TZDateTime(
            location, tomorrowDate.year, tomorrowDate.month, tomorrowDate.day,
            12,),
        calculationParameters: params,
        precision: true,
      );

      Map<PrayerEventId, PrayerEvent> eventsFrom(PrayerTimes pt) => {
            PrayerEventId.fajr: PrayerEvent(
                id: PrayerEventId.fajr, time: _zoned(pt.fajr, location),),
            PrayerEventId.sunrise: PrayerEvent(
                id: PrayerEventId.sunrise, time: _zoned(pt.sunrise, location),),
            PrayerEventId.dhuhr: PrayerEvent(
                id: PrayerEventId.dhuhr, time: _zoned(pt.dhuhr, location),),
            PrayerEventId.asr: PrayerEvent(
                id: PrayerEventId.asr, time: _zoned(pt.asr, location),),
            PrayerEventId.maghrib: PrayerEvent(
                id: PrayerEventId.maghrib, time: _zoned(pt.maghrib, location),),
            PrayerEventId.isha: PrayerEvent(
                id: PrayerEventId.isha, time: _zoned(pt.isha, location),),
          };

      final events = eventsFrom(today);
      final tomorrowFajr = _zoned(tomorrow.fajr, location);

      // Sunnah times: night is Maghrib -> tomorrow's Fajr; Duha is
      // sunrise + 20 min. Same formula as before, now computed once here
      // instead of inside the card's build().
      final maghrib = events[PrayerEventId.maghrib]!.time;
      final sunrise = events[PrayerEventId.sunrise]!.time;
      final night = tomorrowFajr.difference(maghrib);
      final sunnah = SunnahTimes(
        middleOfNight:
            maghrib.add(Duration(milliseconds: night.inMilliseconds ~/ 2)),
        lastThirdOfNight: tomorrowFajr
            .subtract(Duration(milliseconds: night.inMilliseconds ~/ 3)),
        duha: sunrise.add(const Duration(minutes: 20)),
      );

      return PrayerSchedule(
        settings: settings,
        civilDate: civilDay,
        events: events,
        tomorrowFajr: tomorrowFajr,
        sunnah: sunnah,
      );
    } catch (e) {
      logError('Error calculating prayer schedule', e);
      return null;
    }
  }

  static tz.TZDateTime _zoned(DateTime time, tz.Location location) =>
      tz.TZDateTime.from(time, location);
}
