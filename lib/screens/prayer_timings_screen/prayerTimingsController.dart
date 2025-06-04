import 'package:adhan_dart/adhan_dart.dart';
import 'package:get/get.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';

class PrayerTimingsController extends GetxController {
  PrayerTimes? prayerTimings = PrayerTimeings.getPrayersTimings();
  Rx<(Duration, String)> timeLeftForNextPrayer =
      PrayerTimeings.timeLeftForNextPrayer().obs;

  void setPrayerSettings({
    required double lat,
    required double long,
    required String method,
    required String asrCalc,
  }) {
    SharedPreferencesService.setLatitude(lat);
    SharedPreferencesService.setLongitude(long);
    SharedPreferencesService.setMethod(method);
    SharedPreferencesService.setAsrCalculation(asrCalc);

    prayerTimings = PrayerTimeings.getPrayersTimings();
    timeLeftForNextPrayer.value = PrayerTimeings.timeLeftForNextPrayer();
    update();
  }
}

class PrayerTimeings {
  static PrayerTimes? getPrayersTimings() {
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

    return PrayerTimes(
      coordinates: coordinates,
      date: DateTime.now(),
      calculationParameters: params,
      precision: true,
    );
  }

  static (Duration, String) timeLeftForNextPrayer() {
    final prayerTimes = getPrayersTimings();
    if (prayerTimes == null) {
      return (const Duration(hours: 0, minutes: 0, seconds: 0), '');
    }

    String nextPrayer = prayerTimes.nextPrayer();
    DateTime? nextPrayerTime = prayerTimes.timeForPrayer(nextPrayer);

    // Handle case when next prayer is tomorrow's Fajr
    if (nextPrayer == 'fajrafter') {
      nextPrayerTime = prayerTimes.fajrafter;
    }

    if (nextPrayerTime == null) {
      return (const Duration(hours: 0, minutes: 0, seconds: 0), '');
    }

    final timeLeft = nextPrayerTime.difference(DateTime.now());

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
  }

  // Helper method to get current prayer
  static String? getCurrentPrayer() {
    final prayerTimes = getPrayersTimings();
    if (prayerTimes == null) return null;

    return prayerTimes.currentPrayer(date: DateTime.now());
  }

  // Helper method to get all prayer times for display
  static Map<String, DateTime>? getAllPrayerTimes() {
    final prayerTimes = getPrayersTimings();
    if (prayerTimes == null) return null;

    return {
      'fajr': prayerTimes.fajr!,
      'sunrise': prayerTimes.sunrise!,
      'dhuhr': prayerTimes.dhuhr!,
      'asr': prayerTimes.asr!,
      'maghrib': prayerTimes.maghrib!,
      'isha': prayerTimes.isha!,
    };
  }

  // Helper method to get Qibla direction
  static double? getQiblaDirection() {
    final lat = SharedPreferencesService.getLatitude();
    final lng = SharedPreferencesService.getLongitude();

    if (lat == 0.0 || lng == 0.0) return null;

    final coordinates = Coordinates(lat, lng);
    return Qibla.qibla(coordinates);
  }
}
