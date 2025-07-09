// models/calculation_method_info.dart
class CalculationMethodInfo {
  final String
      key; // These keys MUST match adhan_dart's CalculationMethod names
  final String arabicName;

  const CalculationMethodInfo({
    required this.key,
    required this.arabicName,
  });

  static const List<CalculationMethodInfo> methods = [
    // Ensure these keys match the method names in adhan_dart.CalculationMethod
    // e.g., adhan_dart.CalculationMethod.muslimWorldLeague() means key 'muslimWorldLeague'
    CalculationMethodInfo(
        key: 'muslim_world_league', arabicName: 'رابطة العالم الإسلامي'),
    CalculationMethodInfo(
        key: 'egyptian', arabicName: 'الهيئة المصرية العامة للمساحة'),
    CalculationMethodInfo(
        key: 'karachi', arabicName: 'جامعة العلوم الإسلامية، كراتشي'),
    CalculationMethodInfo(
        key: 'umm_al_qura', arabicName: 'جامعة أم القرى، مكة المكرمة'),
    CalculationMethodInfo(
        key: 'dubai', arabicName: 'هيئة دبي للأوقاف والشؤون الإسلامية'),
    CalculationMethodInfo(
        key: 'qatar', arabicName: 'وزارة الأوقاف والشؤون الإسلامية القطرية'),
    CalculationMethodInfo(
        key: 'kuwait', arabicName: 'وزارة الأوقاف والشؤون الإسلامية الكويتية'),
    CalculationMethodInfo(
        key: 'moon_sighting_committee', arabicName: 'لجنة رؤية الهلال'),
    CalculationMethodInfo(
        key: 'singapore', arabicName: 'المجلس الإسلامي في سنغافورة (MUIS)'),
    CalculationMethodInfo(
        key: 'turkey',
        arabicName: 'رئاسة الشؤون الدينية التركية (ديانت)'), // Note: 'turkiye'
    CalculationMethodInfo(
        key: 'tehran', arabicName: 'معهد الجيوفيزياء بجامعة طهران'),
    CalculationMethodInfo(
        key: 'north_america',
        arabicName: 'الجمعية الإسلامية لأمريكا الشمالية (ISNA)'),
    // Add 'other' if you want to allow it, though its parameters are 0 by default.
    // CalculationMethodInfo(key: 'other', arabicName: 'أخرى (مخصص)'),
  ];

  static String getArabicName(String key) {
    try {
      return methods.firstWhere((method) => method.key == key).arabicName;
    } catch (e) {
      print(
          "Warning: Arabic name for adhan_dart calculation method key '$key' not found. Returning key itself.");
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
