import 'package:aldurar_alnaqia/models/consts/ahzab_alshazly_collection.dart';
import 'package:aldurar_alnaqia/models/consts/alhadra_collection.dart';
import 'package:aldurar_alnaqia/models/consts/azkar_algomari_collection.dart';
import 'package:aldurar_alnaqia/models/consts/azkar_morning_evening_collection.dart';
import 'package:aldurar_alnaqia/models/consts/chosen_salawat.dart';
import 'package:aldurar_alnaqia/models/consts/ibn_ata_allah.dart';
import 'package:aldurar_alnaqia/models/consts/poems_collection.dart';
import 'package:aldurar_alnaqia/services/yousria_cycle.dart' as yousria_cycle;
import 'package:aldurar_alnaqia/services/yousria_cycle.dart' show YousriaDayInfo;

class WeekCollectionAzkar {
  static final head = <String>[
    alwazifaZarouquia.title,
    almusabaeat.title,
    alasas.title,
  ];
  static final tail = <String>[
    alhyliaAndNasab.title,
    khitamFawatih.title,
  ];

  static final collection = <List<String>>[
    [hawatfAlhaqaeq.title, monagaIbnAtaAllah.title, hizbAlnasr.title],
    [hizbAlbar.title],
    [
      manzoumaAsmaaHosna.title,
      for (var i = 0; i < chosenSalawatCollection.length; i++)
        chosenSalawatCollection[i].title,
    ],
    [poemBordaBosiri.title],
    [
      alfathAlsedeqy.title,
      poemModaria.title,
      poemMohamadia.title,
      poemmadhWithQuarn.title
    ],
    [hizbAlbahr.title, hizbAlnawawi.title],
    [poemMonfarigaGazali.title, poemMonfarigaNahawi.title, poemBanatSuad.title],
  ];

  static List<String> getDay(int day, {required isToday}) {
    if (isToday) {
      return head + collection[day - 1] + getYousriaForToday() + tail;
    }
    return head + collection[day - 1] + tail;
  }

  // --- Backward-compat forwarders (logic lives in yousria_cycle.dart) ---

  static DateTime islamicEffectiveDate() =>
      yousria_cycle.islamicEffectiveDate();

  static YousriaDayInfo getYousriaDayInfo() =>
      yousria_cycle.getYousriaDayInfo();

  static List<String> getYousriaForToday() =>
      yousria_cycle.getYousriaForToday();
}
