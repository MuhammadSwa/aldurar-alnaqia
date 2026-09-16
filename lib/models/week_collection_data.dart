import 'package:aldurar_alnaqia/models/consts/chosen_salawat.dart';
import 'package:aldurar_alnaqia/services/yousria_cycle.dart'
    show getYousriaForToday;

/// Composition of the 7 day-wirds from stable zikr ids.
///
/// To change a day's wird, edit the id lists below. Display titles,
/// search and audio all resolve through [zikrById], so nothing else
/// needs a manual entry.
class WeekCollectionAzkar {
  static const head = <String>[
    'wazifa-zarouqiyya',
    'musabbaat-ashr',
    'wird-asas',
  ];
  static const tail = <String>[
    'hilya-nasab',
    'khitam-fawatih',
  ];

  /// Index 0 = Monday (day 1) .. index 6 = Sunday (day 7).
  /// Wednesday derives from [chosenSalawatCollection] so reordering that
  /// collection stays in sync automatically.
  static final collection = <List<String>>[
    ['hawatif-haqaiq', 'munajat-ibn-ata-allah', 'hizb-alnasr'],
    ['hizb-albar'],
    ['manzuma-asma-husna', for (final z in chosenSalawatCollection) z.id],
    ['burda-busiri'],
    ['fath-siddiqi', 'qasida-mudariyya', 'qasida-muhammadiyya', 'madh-quran'],
    ['hizb-albahr', 'hizb-alnawawi'],
    ['munfarija-ghazali', 'munfarija-nahwi', 'banat-suad'],
  ];

  static List<String> getDay(int day, {required bool isToday}) {
    if (isToday) {
      return [...head, ...collection[day - 1], ...getYousriaForToday(), ...tail];
    }
    return [...head, ...collection[day - 1], ...tail];
  }
}
