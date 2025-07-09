import 'dart:async';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:get/get.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';

class PrayerTimingsController extends GetxController {
  // Make prayerTimings an Rx variable to be observable.
  final Rx<PrayerTimes?> prayerTimings = Rx<PrayerTimes?>(null);

  /// The current Islamic day of the week (Monday=1, Sunday=7).
  /// This automatically updates after Maghrib.
  final RxInt islamicWeekday = DateTime.now().weekday.obs;

  Rx<(Duration, String)> timeLeftForNextPrayer =
      (const Duration(seconds: 0), '').obs;
  RxBool isInitialized = false.obs;

  Timer? _timer;
  Timer? _dayChangeTimer;

  @override
  void onInit() {
    super.onInit();
    _initializeController();
  }

  @override
  void onClose() {
    _timer?.cancel();
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
      final String? storedTimezone = SharedPreferencesService.getTimezone();
      if (storedTimezone != null && storedTimezone.isNotEmpty) {
        try {
          tz.setLocalLocation(tz.getLocation(storedTimezone));
          print("Using stored timezone: ${tz.local.name}");
        } catch (tzError) {
          print(
              "Failed to load stored timezone '$storedTimezone': $tzError. tz.local remains default (likely UTC).");
        }
      } else {
        print(
            "No stored timezone and native detection failed. tz.local remains default (likely UTC).");
      }
    }

    prayerTimings.value = PrayerTimeings.getPrayersTimings();

    timeLeftForNextPrayer.value = PrayerTimeings.timeLeftForNextPrayer();
    isInitialized.value = true;

    _updateAndScheduleDayChange();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final newTimeLeft = PrayerTimeings.timeLeftForNextPrayer();
      final previousPrayerName = timeLeftForNextPrayer.value.$2;

      timeLeftForNextPrayer.value = newTimeLeft;

      // If we've crossed into a new prayer time (prayer name changed),
      // recalculate prayer timings for the new day if needed (e.g., after Isha).
      if (previousPrayerName != newTimeLeft.$2) {
        prayerTimings.value = PrayerTimeings.getPrayersTimings();
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

    prayerTimings.value = PrayerTimeings.getPrayersTimings();

    timeLeftForNextPrayer.value = PrayerTimeings.timeLeftForNextPrayer();

    // Re-calculate and re-schedule the day change when settings change ---
    _updateAndScheduleDayChange();
    _startTimer();
  }

  void _updateIslamicWeekday() {
    final now = tz.TZDateTime.now(tz.local);
    final prayers = prayerTimings.value;

    if (prayers?.maghrib == null) {
      // Fallback to standard weekday if prayer times aren't available
      islamicWeekday.value = now.weekday;
      return;
    }

    DateTime effectiveDate = now;
    final maghribTime = tz.TZDateTime.from(prayers!.maghrib!, tz.local);

    // If it's already past today's Maghrib, the Islamic day is for tomorrow
    if (now.isAfter(maghribTime)) {
      effectiveDate = now.add(const Duration(days: 1));
    }

    islamicWeekday.value = effectiveDate.weekday;
  }

  // --- NEW METHOD to schedule the next update timer ---
  void _updateAndScheduleDayChange() {
    // 1. Update the day immediately
    _updateIslamicWeekday();

    // 2. Cancel any old timer
    _dayChangeTimer?.cancel();

    // 3. Schedule the next update
    final prayers = prayerTimings.value;
    if (prayers?.maghrib == null) return; // Can't schedule without Maghrib time

    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime nextMaghrib = tz.TZDateTime.from(prayers!.maghrib!, tz.local);

    // If we've already passed today's Maghrib, find tomorrow's
    if (now.isAfter(nextMaghrib)) {
      final tomorrowsPrayers = PrayerTimeings.getPrayersTimings(
          forDate: now.add(const Duration(days: 1)));
      if (tomorrowsPrayers?.maghrib != null) {
        nextMaghrib = tz.TZDateTime.from(tomorrowsPrayers!.maghrib!, tz.local);
      } else {
        return; // Can't schedule if tomorrow's time is unavailable
      }
    }

    final timeUntilNextMaghrib = nextMaghrib.difference(now);

    // Set a timer to fire at the next Maghrib
    _dayChangeTimer = Timer(timeUntilNextMaghrib, () {
      // When it fires, run this whole process again
      _updateAndScheduleDayChange();
    });
  }

  void updateNextPrayer() {
    timeLeftForNextPrayer.value = PrayerTimeings.timeLeftForNextPrayer();
  }
}

// Rest of the PrayerTimeings class remains the same...
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
