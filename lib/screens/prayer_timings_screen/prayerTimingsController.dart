import 'dart:async';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:get/get.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';

class PrayerTimingsController extends GetxController {
  /// --- OPTIMIZATION: Main prayer times object.
  /// This is now the single source of truth for the day's prayer times.
  /// It's only recalculated when necessary (on init, settings change, or day change),
  /// not every second.
  final Rx<PrayerTimes?> prayerTimings = Rx<PrayerTimes?>(null);

  /// The current Islamic day of the week (Monday=1, Sunday=7).
  /// This automatically updates after Maghrib.
  final RxInt islamicWeekday = DateTime.now().weekday.obs;

  /// --- OPTIMIZATION: Now holds the next prayer time and name.
  /// This structure is more efficient than recalculating constantly.
  final Rx<(DateTime?, String)> nextPrayerInfo =
      Rx<(DateTime?, String)>((null, ''));

  /// --- OPTIMIZATION: The countdown duration is now separate.
  /// This is the only value that needs to be updated every second.
  final Rx<Duration> timeLeft = Duration.zero.obs;

  final RxBool isInitialized = false.obs;

  // Timers
  Timer? _countdownTimer; // For the 1-second UI countdown
  Timer? _dayChangeTimer; // For the once-a-day recalculation

  @override
  void onInit() {
    super.onInit();
    _initializeController();
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    _dayChangeTimer?.cancel();
    super.onClose();
  }

  Future<void> _initializeController() async {
    isInitialized.value = false;
    tz.initializeTimeZones();

    try {
      final String localTimezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezoneName));
      SharedPreferencesService.setTimezone(localTimezoneName);
      print("Device timezone set to: ${tz.local.name}");
    } catch (e) {
      print("Failed to get or set local timezone: $e");
      // Fallback to stored timezone
      final String? storedTimezone = SharedPreferencesService.getTimezone();
      if (storedTimezone != null && storedTimezone.isNotEmpty) {
        try {
          tz.setLocalLocation(tz.getLocation(storedTimezone));
          print("Using stored timezone: ${tz.local.name}");
        } catch (tzError) {
          print("Failed to load stored timezone '$storedTimezone': $tzError.");
        }
      }
    }

    // --- OPTIMIZATION: Calculate everything once.
    _recalculateAllPrayerData();
    isInitialized.value = true;
  }

  /// --- OPTIMIZATION: Centralized method to recalculate all prayer data.
  /// This should be called only when data can fundamentally change.
  void _recalculateAllPrayerData() {
    // 1. Calculate and cache prayer times for the current day.
    prayerTimings.value = PrayerTimeings.getPrayersTimings();

    // 2. Determine the next prayer and its time.
    _updateNextPrayerInfo();

    // 3. Schedule the timer for the Islamic day change (at Maghrib).
    _updateAndScheduleDayChange();

    // 4. Start/restart the 1-second countdown timer.
    _startCountdownTimer();
  }

  /// --- OPTIMIZATION: Updates the next prayer info based on the cached prayerTimings.
  void _updateNextPrayerInfo() {
    final prayers = prayerTimings.value;
    if (prayers == null) {
      nextPrayerInfo.value = (null, '');
      return;
    }

    // --- OPTIMIZATION: The adhan_dart logic to find the next prayer is efficient.
    // We call it here, once, instead of inside a loop.
    String nextPrayerNameString = prayers.nextPrayer();
    DateTime? nextPrayerDateTime = prayers.timeForPrayer(nextPrayerNameString);

    // The library returns 'fajrafter' for tomorrow's Fajr. We use that.
    if (nextPrayerNameString == 'fajrafter') {
      nextPrayerDateTime = prayers.fajrafter;
      nextPrayerNameString = 'fajr'; // Standardize the name
    }

    if (nextPrayerDateTime != null) {
      final tz.TZDateTime localNextPrayerTime =
          tz.TZDateTime.from(nextPrayerDateTime, tz.local);
      nextPrayerInfo.value =
          (localNextPrayerTime, _getArabicPrayerName(nextPrayerNameString));
    } else {
      nextPrayerInfo.value = (null, '');
    }
  }

  /// --- OPTIMIZATION: Renamed from _startTimer to be more descriptive.
  /// This timer is now very lightweight. It only calculates a time difference.
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final nextPrayerTime = nextPrayerInfo.value.$1;

      if (nextPrayerTime != null) {
        final now = tz.TZDateTime.now(tz.local);
        final newTimeLeft = nextPrayerTime.difference(now);

        // If time is up, it's time to recalculate the *next* prayer.
        if (newTimeLeft.isNegative) {
          // This will find the new next prayer and update the countdown target.
          _updateNextPrayerInfo();
        } else {
          timeLeft.value = newTimeLeft;
        }
      }
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

    // --- OPTIMIZATION: Simply call the master recalculation method.
    _recalculateAllPrayerData();
  }

  // This method efficiently determines the Islamic weekday based on Maghrib time.
  // Its logic was already good and remains unchanged.
  void _updateIslamicWeekday() {
    final now = tz.TZDateTime.now(tz.local);
    final prayers = prayerTimings.value;

    if (prayers?.maghrib == null) {
      islamicWeekday.value = now.weekday; // Fallback
      return;
    }

    final maghribTime = tz.TZDateTime.from(prayers!.maghrib!, tz.local);
    DateTime effectiveDate = now;
    if (now.isAfter(maghribTime)) {
      effectiveDate = now.add(const Duration(days: 1));
    }
    islamicWeekday.value = effectiveDate.weekday;
  }

  // This method efficiently schedules a SINGLE timer to fire at the next Maghrib.
  // This is excellent for battery life. Its logic was already good.
  void _updateAndScheduleDayChange() {
    _updateIslamicWeekday();
    _dayChangeTimer?.cancel();

    final prayers = prayerTimings.value;
    if (prayers?.maghrib == null) return;

    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime nextMaghrib = tz.TZDateTime.from(prayers!.maghrib!, tz.local);

    if (now.isAfter(nextMaghrib)) {
      final tomorrowsPrayers = PrayerTimeings.getPrayersTimings(
          forDate: now.add(const Duration(days: 1)));
      if (tomorrowsPrayers?.maghrib != null) {
        nextMaghrib = tz.TZDateTime.from(tomorrowsPrayers!.maghrib!, tz.local);
      } else {
        return;
      }
    }

    final timeUntilNextMaghrib = nextMaghrib.difference(now);

    // This single timer will fire and then trigger a full data refresh.
    _dayChangeTimer = Timer(timeUntilNextMaghrib, () {
      // Once Maghrib hits, recalculate everything for the new Islamic day.
      _recalculateAllPrayerData();
    });
  }

  // Helper to map English prayer names from the library to Arabic.
  String _getArabicPrayerName(String englishName) {
    switch (englishName.toLowerCase()) {
      case 'fajr':
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
      // Use tz.local, which should have been configured in PrayerTimingsController.onInit
      // Create timezone-aware current date using the device's local timezone
      final tz.TZDateTime dateForCalculation = forDate != null
          ? tz.TZDateTime.from(forDate, tz.local)
          : tz.TZDateTime.now(tz.local);

      final CalculationParameters params;
      switch (method) {
        case 'egyptian':
          params = CalculationMethod.egyptian();
          break;
        case 'karachi':
          params = CalculationMethod.karachi();
          break;
        case 'muslim_world_league':
          params = CalculationMethod.muslimWorldLeague();
          break;
        case 'dubai':
          params = CalculationMethod.dubai();
          break;
        case 'qatar':
          params = CalculationMethod.qatar();
          break;
        case 'kuwait':
          params = CalculationMethod.kuwait();
          break;
        case 'turkey':
          params = CalculationMethod.turkiye();
          break;
        case 'tehran':
          params = CalculationMethod.tehran();
          break;
        case 'singapore':
          params = CalculationMethod.singapore();
          break;
        case 'umm_al_qura':
          params = CalculationMethod.ummAlQura();
          break;
        case 'north_america':
          params = CalculationMethod.northAmerica();
          break;
        case 'moon_sighting_committee':
          params = CalculationMethod.moonsightingCommittee();
          break;
        default:
          params = CalculationMethod.other();
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
      print('Error initializing prayer times: $e');
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

      String nextPrayer = prayerTimes.nextPrayer();
      DateTime? nextPrayerTime = prayerTimes.timeForPrayer(nextPrayer);

      // Handle case when next prayer is tomorrow's Fajr
      if (nextPrayer == 'fajrafter') {
        nextPrayerTime = prayerTimes.fajrafter;
      }

      if (nextPrayerTime == null) {
        return (const Duration(hours: 0, minutes: 0, seconds: 0), '');
      }

      // Convert to local timezone
      final tz.TZDateTime localNextPrayerTime =
          tz.TZDateTime.from(nextPrayerTime, tz.local);
      final timeLeft = localNextPrayerTime.difference(now);

      final String prayerName;
      switch (nextPrayer) {
        case 'fajr':
        case 'fajrafter':
          prayerName = 'الفجر';
          break;
        case 'sunrise':
          prayerName = 'الشروق';
          break;
        case 'dhuhr':
          prayerName = 'الظهر';
          break;
        case 'asr':
          prayerName = 'العصر';
          break;
        case 'maghrib':
          prayerName = 'المغرب';
          break;
        case 'isha':
          prayerName = 'العشاء';
          break;
        default:
          prayerName = 'الفجر';
          break;
      }

      return (timeLeft, prayerName);
    } catch (e) {
      print('Error calculating time left for next prayer: $e');
      return (const Duration(hours: 0, minutes: 0, seconds: 0), '');
    }
  }

  // Helper method to get current prayer
  static String? getCurrentPrayer() {
    final prayerTimes = getPrayersTimings();
    if (prayerTimes == null) return null;

    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      return prayerTimes.currentPrayer(date: now);
    } catch (e) {
      print('Error getting current prayer: $e');
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
        'fajr': tz.TZDateTime.from(prayerTimes.fajr!, timezone),
        'sunrise': tz.TZDateTime.from(prayerTimes.sunrise!, timezone),
        'dhuhr': tz.TZDateTime.from(prayerTimes.dhuhr!, timezone),
        'asr': tz.TZDateTime.from(prayerTimes.asr!, timezone),
        'maghrib': tz.TZDateTime.from(prayerTimes.maghrib!, timezone),
        'isha': tz.TZDateTime.from(prayerTimes.isha!, timezone),
      };
    } catch (e) {
      print('Error getting prayer times: $e');
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

      final fajr = tz.TZDateTime.from(prayerTimes.fajr!, timezone);
      final isha = tz.TZDateTime.from(prayerTimes.isha!, timezone);
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
