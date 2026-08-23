import 'dart:async';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/common/helpers/logger.dart';

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
  }) {
    SharedPreferencesService.setLatitude(lat);
    SharedPreferencesService.setLongitude(long);
    SharedPreferencesService.setMethod(method);
    SharedPreferencesService.setAsrCalculation(asrCalc);
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
    DateTime effectiveDate = now;
    if (now.isAfter(maghribTime)) {
      effectiveDate = now.add(const Duration(days: 1));
    }
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

/// Maps English prayer names from the library to Arabic.
String arabicPrayerName(String englishName) {
    switch (englishName.toLowerCase()) {
      case 'fajr':
      case 'fajrafter':
        return 'الفجر';
    case 'sunrise':
      return 'الشروق';
    case 'dhuhr':
      return 'الظهر';
    case 'asr':
      return 'العصر';
    case 'maghrib':
      return 'المغرب';
    case 'isha':
      return 'العشاء';
    default:
      return 'الفجر'; // Sensible default
  }
}

/// The current Islamic weekday (after Maghrib the next day begins),
/// computed without needing a running notifier — safe for routing.
int islamicWeekdayNow() {
  final now = tz.TZDateTime.now(tz.local);
  final maghrib = PrayerTimeings.getPrayersTimings()?.maghrib;
  if (maghrib == null) return now.weekday;
  final maghribTime = tz.TZDateTime.from(maghrib, tz.local);
  if (now.isAfter(maghribTime)) return now.add(const Duration(days: 1)).weekday;
  return now.weekday;
}

class PrayerTimeings {
  static PrayerTimes? getPrayersTimings({DateTime? forDate}) {
    Coordinates coordinates = Coordinates(
      SharedPreferencesService.getLatitude(),
      SharedPreferencesService.getLongitude(),
    );
    final method = SharedPreferencesService.getMethod();
    final asrCalc = SharedPreferencesService.getAsrCalculation();

    if (method == '' ||
        asrCalc == '' ||
        coordinates.latitude == 0.0 ||
        coordinates.longitude == 0.0) {
      return null;
    }

    try {
      // Use tz.local, which should have been configured in
      // PrayerTimingsNotifier._initialize.
      final tz.TZDateTime dateForCalculation = forDate != null
          ? tz.TZDateTime.from(forDate, tz.local)
          : tz.TZDateTime.now(tz.local);

      final CalculationParameters params;
      switch (method) {
        case 'egyptian':
          params = CalculationMethodParameters.egyptian();
          break;
        case 'karachi':
          params = CalculationMethodParameters.karachi();
          break;
        case 'muslim_world_league':
          params = CalculationMethodParameters.muslimWorldLeague();
          break;
        case 'dubai':
          params = CalculationMethodParameters.dubai();
          break;
        case 'qatar':
          params = CalculationMethodParameters.qatar();
          break;
        case 'kuwait':
          params = CalculationMethodParameters.kuwait();
          break;
        case 'turkey':
          params = CalculationMethodParameters.turkiye();
          break;
        case 'tehran':
          params = CalculationMethodParameters.tehran();
          break;
        case 'singapore':
          params = CalculationMethodParameters.singapore();
          break;
        case 'umm_al_qura':
          params = CalculationMethodParameters.ummAlQura();
          break;
        case 'north_america':
          params = CalculationMethodParameters.northAmerica();
          break;
        case 'moon_sighting_committee':
          params = CalculationMethodParameters.moonsightingCommittee();
          break;
        default:
          params = CalculationMethodParameters.other();
          break;
      }

      if (asrCalc == 'shafi') {
        params.madhab = Madhab.shafi;
      } else {
        params.madhab = Madhab.hanafi;
      }

      // Handle high latitude locations with configurable rules
      final highLatRule = SharedPreferencesService.getHighLatitudeRule();
      if (coordinates.latitude.abs() > 48.0) {
        switch (highLatRule) {
          case 'middle_of_night':
            params.highLatitudeRule = HighLatitudeRule.middleOfTheNight;
            break;
          case 'seventh_of_night':
            params.highLatitudeRule = HighLatitudeRule.seventhOfTheNight;
            break;
          case 'twilight_angle':
            params.highLatitudeRule = HighLatitudeRule.twilightAngle;
            break;
          default:
            // Default to middle of night for high latitudes
            params.highLatitudeRule = HighLatitudeRule.middleOfTheNight;
            break;
        }
      }

      return PrayerTimes(
        coordinates: coordinates,
        date: dateForCalculation, // Use timezone-aware date
        calculationParameters: params,
        precision: true,
      );
    } catch (e) {
      // Handle timezone errors
      logError('Error initializing prayer times', e);
      return null;
    }
  }

  static (Duration, String) timeLeftForNextPrayer() {
    final prayerTimes = getPrayersTimings();
    if (prayerTimes == null) {
      return (const Duration(hours: 0, minutes: 0, seconds: 0), '');
    }

    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

      final nextPrayer = prayerTimes.nextPrayer();
      String nextPrayerName = nextPrayer.name;
      DateTime nextPrayerTime = prayerTimes.timeForPrayer(nextPrayer);

      // Handle case when next prayer is tomorrow's Fajr
      if (nextPrayer == Prayer.fajrAfter) {
        nextPrayerTime = prayerTimes.fajrAfter;
        nextPrayerName = 'fajr';
      }

      // Convert to local timezone
      final tz.TZDateTime localNextPrayerTime =
          tz.TZDateTime.from(nextPrayerTime, tz.local);
      final timeLeft = localNextPrayerTime.difference(now);

      return (timeLeft, arabicPrayerName(nextPrayerName));
    } catch (e) {
      logError('Error calculating time left for next prayer', e);
      return (const Duration(hours: 0, minutes: 0, seconds: 0), '');
    }
  }

  // Helper method to get current prayer
  static String? getCurrentPrayer() {
    final prayerTimes = getPrayersTimings();
    if (prayerTimes == null) return null;

    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      return prayerTimes.currentPrayer(date: now).name;
    } catch (e) {
      logError('Error getting current prayer', e);
      return null;
    }
  }

  // Helper method to get all prayer times for display (in local timezone)
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

  // Helper method to get formatted prayer times
  static Map<String, String>? getFormattedPrayerTimes(
      {String format = 'HH:mm'}) {
    final prayerTimes = getAllPrayerTimes();
    if (prayerTimes == null) return null;

    return {
      'fajr': _formatTime(prayerTimes['fajr']!, format),
      'sunrise': _formatTime(prayerTimes['sunrise']!, format),
      'dhuhr': _formatTime(prayerTimes['dhuhr']!, format),
      'asr': _formatTime(prayerTimes['asr']!, format),
      'maghrib': _formatTime(prayerTimes['maghrib']!, format),
      'isha': _formatTime(prayerTimes['isha']!, format),
    };
  }

  // Private helper method to format time
  static String _formatTime(tz.TZDateTime dateTime, String format) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');

    switch (format) {
      case 'HH:mm':
        return '$hour:$minute';
      case 'HH:mm:ss':
        return '$hour:$minute:$second';
      case 'h:mm a':
        final hour12 = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
        final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
        return '${hour12.toString().padLeft(1, '0')}:$minute $amPm';
      default:
        return '$hour:$minute';
    }
  }

  // Helper method to get Qibla direction
  static double? getQiblaDirection() {
    final lat = SharedPreferencesService.getLatitude();
    final lng = SharedPreferencesService.getLongitude();

    if (lat == 0.0 || lng == 0.0) return null;

    final coordinates = Coordinates(lat, lng);
    return Qibla.qibla(coordinates);
  }

  // Helper method to check if location needs high latitude rules
  static bool needsHighLatitudeRule() {
    final lat = SharedPreferencesService.getLatitude();
    return lat.abs() > 48.0;
  }

  // Helper method to get recommended high latitude rule based on location
  static String getRecommendedHighLatitudeRule() {
    final lat = SharedPreferencesService.getLatitude();

    if (lat.abs() > 65.0) {
      return 'middle_of_night';
    } else if (lat.abs() > 55.0) {
      return 'seventh_of_night';
    } else if (lat.abs() > 48.0) {
      return 'twilight_angle';
    }

    return 'none';
  }

  // Helper method to validate prayer times and detect potential issues
  static Map<String, dynamic> validatePrayerTimes() {
    final prayerTimes = getPrayersTimings();
    final lat = SharedPreferencesService.getLatitude();

    if (prayerTimes == null) {
      return {
        'isValid': false,
        'error': 'Unable to calculate prayer times',
        'recommendation': null,
      };
    }

    try {
      final timezone = tz.local;

      final fajr = tz.TZDateTime.from(prayerTimes.fajr, timezone);
      final isha = tz.TZDateTime.from(prayerTimes.isha, timezone);
      final timeDiff = isha.difference(fajr);

      bool hasIssues = false;
      String? recommendation;

      if (lat.abs() > 48.0) {
        if (timeDiff.inHours < 8 || timeDiff.inHours > 20) {
          hasIssues = true;
          recommendation =
              'Consider using ${getRecommendedHighLatitudeRule()} high latitude rule';
        }
      }

      return {
        'isValid': !hasIssues,
        'needsHighLatitudeRule': needsHighLatitudeRule(),
        'recommendedRule': getRecommendedHighLatitudeRule(),
        'recommendation': recommendation,
        'latitude': lat,
        'timezone': timezone.name,
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': 'Timezone error: $e',
        'recommendation': 'Check timezone settings',
      };
    }
  }
}
