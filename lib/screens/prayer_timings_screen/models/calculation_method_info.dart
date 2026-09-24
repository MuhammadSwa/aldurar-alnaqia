// models/calculation_method_info.dart
import 'package:aldurar_alnaqia/common/helpers/logger.dart';
import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart'
    show PrayerMethods;

class CalculationMethodInfo {

  const CalculationMethodInfo({
    required this.key,
    required this.arabicName,
  });
  final String
      key; // These keys MUST match adhan_dart's CalculationMethod names
  final String arabicName;

  static const List<CalculationMethodInfo> methods = [
    // Keys MUST match [PrayerMethods] (the cross-platform contract).
    CalculationMethodInfo(
        key: PrayerMethods.muslimWorldLeague, arabicName: 'رابطة العالم الإسلامي',),
    CalculationMethodInfo(
        key: PrayerMethods.egyptian, arabicName: 'الهيئة المصرية العامة للمساحة',),
    CalculationMethodInfo(
        key: PrayerMethods.karachi, arabicName: 'جامعة العلوم الإسلامية، كراتشي',),
    CalculationMethodInfo(
        key: PrayerMethods.ummAlQura, arabicName: 'جامعة أم القرى، مكة المكرمة',),
    CalculationMethodInfo(
        key: PrayerMethods.dubai, arabicName: 'هيئة دبي للأوقاف والشؤون الإسلامية',),
    CalculationMethodInfo(
        key: PrayerMethods.qatar, arabicName: 'وزارة الأوقاف والشؤون الإسلامية القطرية',),
    CalculationMethodInfo(
        key: PrayerMethods.kuwait, arabicName: 'وزارة الأوقاف والشؤون الإسلامية الكويتية',),
    CalculationMethodInfo(
        key: PrayerMethods.moonSightingCommittee, arabicName: 'لجنة رؤية الهلال',),
    CalculationMethodInfo(
        key: PrayerMethods.singapore, arabicName: 'المجلس الإسلامي في سنغافورة (MUIS)',),
    CalculationMethodInfo(
        key: PrayerMethods.turkey,
        arabicName: 'رئاسة الشؤون الدينية التركية (ديانت)',), // Note: 'turkiye'
    CalculationMethodInfo(
        key: PrayerMethods.tehran, arabicName: 'معهد الجيوفيزياء بجامعة طهران',),
    CalculationMethodInfo(
        key: PrayerMethods.northAmerica,
        arabicName: 'الجمعية الإسلامية لأمريكا الشمالية (ISNA)',),
  ];

  static String getArabicName(String key) {
    try {
      return methods.firstWhere((method) => method.key == key).arabicName;
    } catch (e) {
      // Unknown key: visible fallback, never a silent wrong method.
      logWarn('Unknown calculation method key "$key"');
      return key;
    }
  }

  static String? getKeyFromArabicName(String arabicName) {
    try {
      return methods
          .firstWhere((method) => method.arabicName == arabicName)
          .key;
    } catch (e) {
      return null; // Not found
    }
  }
}
