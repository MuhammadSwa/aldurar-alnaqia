// TODO: rethink the entire model system.

import 'package:yosria/models/consts/ahzab_alshazly_collection.dart';
import 'package:yosria/models/consts/alhadra_collection.dart';
import 'package:yosria/models/consts/azkar_algomari_collection.dart';
import 'package:yosria/models/consts/azkar_morning_evening_collection.dart';
import 'package:yosria/models/consts/chosen_salawat.dart';
import 'package:yosria/models/consts/dalayil_alkhayrat_collection.dart';
import 'package:yosria/models/consts/orphans.dart';
import 'package:yosria/models/consts/poems_collection.dart';
import 'package:yosria/models/consts/salawat_yousria_collection.dart';
import 'package:yosria/models/consts/tareeqa_bios_collection.dart';
import 'package:yosria/models/consts/ibn_ataAllah.dart';

class Zikr {
  final String title;
  final String content;
  final String notes;
  final String footer;
  final String? url;
  const Zikr({
    required this.content,
    this.url,
    this.title = '',
    this.notes = '',
    this.footer = '',
  });
}


class AllAzkar {
  final Map<String, Zikr> azkarCategMap;
  const AllAzkar({required this.azkarCategMap});

  get allAzkar => azkarCategMap;

  List<String> getTitles() {
    List<String> titles = [];
    azkarCategMap.forEach((key, value) {
      titles.add(key);
    });
    return titles;
  }
}

// === All Azkar ===

// TODO: a better way to add to allaZkar
final allAzkar = AllAzkar(azkarCategMap: {
  // === morningEveningAzkarCollection ===
  alasas.title: alasas,
  almusabaeat.title: almusabaeat,
  alwazifaZarouquia.title: alwazifaZarouquia,
  almarefAlzawquia.title: almarefAlzawquia,
  khitamFawatih.title: khitamFawatih,

  /// === algomariAzkarCollection ===
  alfathAlsedeqy.title: alfathAlsedeqy,
  azkarSalatGomari.title: azkarSalatGomari,
  azkarAfterSalat.title: azkarAfterSalat,

  /// === ahzabAlshazlyCollection ===
  hizbAlbahr.title: hizbAlbahr,
  hizbAlbar.title: hizbAlbar,
  hizbAlnasr.title: hizbAlnasr,
  hizbAlnawawi.title: hizbAlnawawi,

  /// === salawatYousriaCollection ===
  // salawatYousria.title: salawatYousria,
  // salawatYousriaExplain.title: salawatYousriaExplain,
  day1Yousria.title: day1Yousria,
  day2Yousria.title: day2Yousria,
  day3Yousria.title: day3Yousria,
  day4Yousria.title: day4Yousria,
  day5Yousria.title: day5Yousria,
  day6Yousria.title: day6Yousria,
  salawatYousriaIntro.title: salawatYousriaIntro,
  asmaaAllahHadith.title: asmaaAllahHadith,
  salawatYousria.title: salawatYousria,

  /// === dalayilAlkhayratCollection ===
  // dalayilAlkhayratIntro.title: dalayilAlkhayratIntro,
  // namesOfTheProphetPBUH.title: namesOfTheProphetPBUH,
  dalayilHizb1.title: dalayilHizb1,
  dalayilHizb2.title: dalayilHizb2,
  dalayilHizb3.title: dalayilHizb3,
  dalayilHizb4.title: dalayilHizb4,
  dalayilHizb5.title: dalayilHizb5,
  dalayilHizb6.title: dalayilHizb6,
  dalayilHizb7.title: dalayilHizb7,
  // dalayilHizb8.title: dalayilHizb8,
  // dalayilWrapUp.title: dalayilWrapUp,

  //
  poemmadhWithQuarn.title: poemmadhWithQuarn,
  poemModaria.title: poemModaria,
  poemMohamadia.title: poemMohamadia,
  poemBordaBosiri.title: poemBordaBosiri,
  manzoumaAsmaaHosna.title: manzoumaAsmaaHosna,
  poemMonfarigaGazali.title: poemMonfarigaGazali,
  poemMonfarigaNahawi.title: poemMonfarigaNahawi,
  duaaEstighatha.title: duaaEstighatha,
  poemBanatSuad.title: poemBanatSuad,

  //
  salahAzimia.title: salahAzimia,
  salahIbnBashish.title: salahIbnBashish,
  salahAlbaha.title: salahAlbaha,
  salahAlfateh.title: salahAlfateh,
  salahAlmohtag.title: salahAlmohtag,
  salahAlmotardy.title: salahAlmotardy,
  salahNoorania.title: salahNoorania,
  salahAlqasm.title: salahAlqasm,
  salahAlshafia.title: salahAlshafia,
  salahZatia.title: salahZatia,

  //
  drYousryGabrBio.title: drYousryGabrBio,
  abdallahGomariBio.title: abdallahGomariBio,

  // hadraCollection
  hadraPrayerAfterAzkar.title: hadraPrayerAfterAzkar,
  yaRasoulAllah.title: yaRasoulAllah,

// orphans
  sanadAltareeqa.title: sanadAltareeqa,
  monagaIbnAtaAllah.title: monagaIbnAtaAllah,
  hawatfAlhaqaeq.title: hawatfAlhaqaeq,
  adabAltareeqa.title: adabAltareeqa,
  waseyaGamea.title: waseyaGamea,
  asrGomaa.title: asrGomaa,

  // NOTE: i'm doing this so it can appear on search
  alhyliaAndNasab.title: alhyliaAndNasab,
});

// azkar that doesn't belong to any collection.
final orphanAzkar = AllAzkar(azkarCategMap: {
  sanadAltareeqa.title: sanadAltareeqa,
  adabAltareeqa.title: adabAltareeqa,
  waseyaGamea.title: waseyaGamea,
  asrGomaa.title: asrGomaa,
});

class AzkarCollections {
  final Map<String, List<Zikr>> azkarCategList;
  const AzkarCollections({required this.azkarCategList});

  List<String> getTitles() {
    List<String> titles = [];
    azkarCategList.forEach((key, value) {
      titles.add(key);
    });
    return titles;
  }

  List<String> getAzkarTitles(String title) {
    List<String> titles = [];
    // TODO? use a for loop instead?
    azkarCategList[title]!.forEach((categ) {
      titles.add(categ.title);
    });
    return titles;
  }
}

const azkarCollections = AzkarCollections(
  azkarCategList: {
    // 'الأوراد اليومية': morningEveningAzkarCollection,
    'الحضرة الصديقية': alhadraCollection,
    'الصلوات اليسرية': salawatYousriaCollection,
    'دلائل الخيرات': dalayilAlkhayratCollection,
    'أوارد سيدي عبد الله بن الصديق الغماري': azkarAlgomariCollection,
    'الأحزاب': ahzabCollection,
    'قصائد': poemsCollection,
    'صلوات مختارة على النبي ﷺ': chosenSalawatCollection,
    'أوراد سيدي ابن عطاء الله': ibnAtaAllahCollection,
    'تراجم رجال الطريقة': tareeqaBiosCollection,
  },
);

// TODO: refactor and rethink this
// 'collectiontitle':[]
// map string => zikrs
final azkarWithNarrations = <String, List<Zikr>>{
  'دلائل الخيرات': [
    dalayilHizb1,
    dalayilHizb2,
    dalayilHizb3,
    dalayilHizb4,
    dalayilHizb5,
    dalayilHizb6,
    dalayilHizb7,
  ],
  'الصلوات اليسرية': [
    day1Yousria,
    day2Yousria,
    day3Yousria,
    day4Yousria,
    day5Yousria,
    day6Yousria,
  ]
};
