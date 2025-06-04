// models/calculation_method_info.dart
class CalculationMethodInfo {
  final String key;
  final String arabicName;

  const CalculationMethodInfo({
    required this.key,
    required this.arabicName,
  });

  static const List<CalculationMethodInfo> methods = [
    CalculationMethodInfo(key: 'egyptian', arabicName: 'مصر'),
    CalculationMethodInfo(key: 'karachi', arabicName: 'كراتشي'),
    CalculationMethodInfo(
        key: 'muslim_world_league', arabicName: 'رابطة العالم الإسلامي'),
    CalculationMethodInfo(key: 'dubai', arabicName: 'دبي'),
    CalculationMethodInfo(key: 'qatar', arabicName: 'قطر'),
    CalculationMethodInfo(key: 'kuwait', arabicName: 'الكويت'),
    CalculationMethodInfo(key: 'turkey', arabicName: 'تركيا'),
    CalculationMethodInfo(key: 'tehran', arabicName: 'طهران'),
    CalculationMethodInfo(key: 'singapore', arabicName: 'سنغافورة'),
    CalculationMethodInfo(key: 'umm_al_qura', arabicName: 'أم القرى'),
    CalculationMethodInfo(key: 'north_america', arabicName: 'أمريكا الشمالية'),
    CalculationMethodInfo(
        key: 'moon_sighting_committee', arabicName: 'لجنة رؤية القمر'),
  ];

  static String getArabicName(String key) {
    return methods
        .firstWhere(
          (method) => method.key == key,
          orElse: () =>
              const CalculationMethodInfo(key: 'other', arabicName: 'أخرى'),
        )
        .arabicName;
  }
}
