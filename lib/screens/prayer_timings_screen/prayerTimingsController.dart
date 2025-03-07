import 'package:adhan/adhan.dart';
import 'package:get/get.dart';
import 'package:yosria/services/shared_prefs.dart';

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
    Coordinates myCoordinates = Coordinates(
      SharedPreferencesService.getLatitude(),
      SharedPreferencesService.getLongitude(),
    );
    final method = SharedPreferencesService.getMethod();
    final asrCalc = SharedPreferencesService.getAsrCalculation();
    if (method == '' ||
        asrCalc == '' ||
        myCoordinates.latitude == 0.0 ||
        myCoordinates.longitude == 0.0) {
      return null;
    }

    final CalculationParameters params;
    switch (method) {
      case 'egyptian':
        params = CalculationMethod.egyptian.getParameters();
        break;
      case 'karachi':
        params = CalculationMethod.karachi.getParameters();
        break;
      case 'muslim_world_league':
        params = CalculationMethod.muslim_world_league.getParameters();
        break;
      case 'dubai':
        params = CalculationMethod.dubai.getParameters();
      case 'qatar':
        params = CalculationMethod.qatar.getParameters();
      case 'kuwait':
        params = CalculationMethod.kuwait.getParameters();
      case 'turkey':
        params = CalculationMethod.turkey.getParameters();
      case 'tehran':
        params = CalculationMethod.tehran.getParameters();
      case 'singapore':
        params = CalculationMethod.singapore.getParameters();
      case 'umm_al_qura':
        params = CalculationMethod.umm_al_qura.getParameters();
      case 'north_america':
        params = CalculationMethod.north_america.getParameters();
      case 'moon_sighting_committee':
        params = CalculationMethod.moon_sighting_committee.getParameters();
        break;
      default:
        params = CalculationMethod.other.getParameters();
        break;
    }

    if (asrCalc == 'shafi') {
      params.madhab = Madhab.shafi;
    } else {
      params.madhab = Madhab.hanafi;
    }

    return PrayerTimes.today(myCoordinates, params);
  }

  static (Duration, String) timeLeftForNextPrayer() {
    final prayerTimes = getPrayersTimings();
    if (prayerTimes == null) {
      return (const Duration(hours: 0, minutes: 0, seconds: 0), '');
    }

    Prayer nextPrayer = prayerTimes.nextPrayer();
    DateTime? nextPrayerTime = prayerTimes.timeForPrayer(nextPrayer);
    if (nextPrayer == Prayer.none) {
      nextPrayer = Prayer.fajr;
      nextPrayerTime =
          prayerTimes.timeForPrayer(nextPrayer)!.add(const Duration(days: 1));
    }

    final timeLeft =
        // nextPrayerTime!.difference(DateTime.now()).toString().split('.').first;
        nextPrayerTime!.difference(DateTime.now());

    final String prayerName;
    switch (prayerTimes.nextPrayer()) {
      case Prayer.none:
        prayerName = 'الفجر';
        break;
      case Prayer.fajr:
        prayerName = 'الفجر';
        break;
      case Prayer.sunrise:
        prayerName = 'الشروق';
        break;
      case Prayer.dhuhr:
        prayerName = 'الظهر';
        break;
      case Prayer.asr:
        prayerName = 'العصر';
        break;
      case Prayer.maghrib:
        prayerName = 'المغرب';
        break;
      case Prayer.isha:
        prayerName = 'العشاء';
        break;
    }
    // return '$prayerName بعد $timeLeft';
    return (timeLeft, prayerName);
  }
}
