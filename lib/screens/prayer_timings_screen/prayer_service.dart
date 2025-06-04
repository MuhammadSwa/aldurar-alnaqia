// services/prayer_service.dart
import 'package:adhan/adhan.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/next_prayer_info.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/prayer_settings.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/prayer_timeData.dart';
import 'package:hijri/hijri_calendar.dart';

class PrayerService {
  static const Map<String, String> _prayerNames = {
    'fajr': 'الفجر',
    'sunrise': 'الشروق',
    'dhuhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء',
  };

  static PrayerTimes? calculatePrayerTimes(PrayerSettings settings) {
    if (!settings.isValid) return null;

    final coordinates = Coordinates(settings.latitude, settings.longitude);
    final params = _getCalculationParameters(
      settings.calculationMethod,
      settings.asrCalculation,
    );

    return PrayerTimes.today(coordinates, params);
  }

  static CalculationParameters _getCalculationParameters(
    String method,
    String asrCalc,
  ) {
    CalculationParameters params;

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
        break;
      case 'qatar':
        params = CalculationMethod.qatar.getParameters();
        break;
      case 'kuwait':
        params = CalculationMethod.kuwait.getParameters();
        break;
      case 'turkey':
        params = CalculationMethod.turkey.getParameters();
        break;
      case 'tehran':
        params = CalculationMethod.tehran.getParameters();
        break;
      case 'singapore':
        params = CalculationMethod.singapore.getParameters();
        break;
      case 'umm_al_qura':
        params = CalculationMethod.umm_al_qura.getParameters();
        break;
      case 'north_america':
        params = CalculationMethod.north_america.getParameters();
        break;
      case 'moon_sighting_committee':
        params = CalculationMethod.moon_sighting_committee.getParameters();
        break;
      default:
        params = CalculationMethod.other.getParameters();
    }

    params.madhab = asrCalc == 'shafi' ? Madhab.shafi : Madhab.hanafi;
    return params;
  }

  static NextPrayerInfo? getNextPrayerInfo(PrayerTimes prayerTimes) {
    final now = DateTime.now();
    Prayer nextPrayer = prayerTimes.nextPrayer();
    DateTime? nextPrayerTime = prayerTimes.timeForPrayer(nextPrayer);

    // Handle case when no more prayers today
    if (nextPrayer == Prayer.none) {
      nextPrayer = Prayer.fajr;
      nextPrayerTime =
          prayerTimes.timeForPrayer(nextPrayer)!.add(const Duration(days: 1));
    }

    if (nextPrayerTime == null) return null;

    final timeRemaining = nextPrayerTime.difference(now);
    final prayerName = _prayerNames[nextPrayer.name] ?? nextPrayer.name;

    return NextPrayerInfo(
      name: prayerName,
      timeRemaining: timeRemaining,
      nextPrayerTime: nextPrayerTime,
    );
  }

  static List<PrayerTimeData> getAllPrayerTimes(PrayerTimes prayerTimes) {
    final sunnahTimes = SunnahTimes(prayerTimes);
    final duhaTime = prayerTimes.sunrise.add(const Duration(minutes: 20));

    return [
      PrayerTimeData(name: 'المغرب', time: prayerTimes.maghrib),
      PrayerTimeData(name: 'العشاء', time: prayerTimes.isha),
      PrayerTimeData(
        name: 'منتصف الليل',
        time: sunnahTimes.middleOfTheNight,
        isMainPrayer: false,
      ),
      PrayerTimeData(
        name: 'الثلث الأخير',
        time: sunnahTimes.lastThirdOfTheNight,
        isMainPrayer: false,
      ),
      PrayerTimeData(name: 'الفجر', time: prayerTimes.fajr),
      PrayerTimeData(
          name: 'الشروق', time: prayerTimes.sunrise, isMainPrayer: false),
      PrayerTimeData(name: 'الضحى', time: duhaTime, isMainPrayer: false),
      PrayerTimeData(name: 'الظهر', time: prayerTimes.dhuhr),
      PrayerTimeData(name: 'العصر', time: prayerTimes.asr),
    ];
  }

  static HijriCalendar getHijriDate({int offset = 0}) {
    HijriCalendar.setLocal('ar');
    final adjustedDate = DateTime.now().add(Duration(days: offset));
    return HijriCalendar.fromDate(adjustedDate);
  }

  static HijriCalendar getHijriDateWithMaghrib({
    int offset = 0,
    DateTime? maghribTime,
  }) {
    HijriCalendar.setLocal('ar');
    final now = DateTime.now();
    final adjustedDate = DateTime.now().add(Duration(days: offset));

    if (maghribTime != null && now.isAfter(maghribTime)) {
      return HijriCalendar.fromDate(adjustedDate.add(const Duration(days: 1)));
    }

    return HijriCalendar.fromDate(adjustedDate);
  }
}
