import 'package:aldurar_alnaqia/models/consts/ahzab_alshazly_collection.dart';
import 'package:aldurar_alnaqia/models/consts/alhadra_collection.dart';
import 'package:aldurar_alnaqia/models/consts/azkar_algomari_collection.dart';
import 'package:aldurar_alnaqia/models/consts/azkar_morning_evening_collection.dart';
import 'package:aldurar_alnaqia/models/consts/chosen_salawat.dart';
import 'package:aldurar_alnaqia/models/consts/dalayil_alkhayrat_collection.dart';
import 'package:aldurar_alnaqia/models/consts/orphans.dart';
import 'package:aldurar_alnaqia/models/consts/poems_collection.dart';
import 'package:aldurar_alnaqia/models/consts/salawat_yousria_collection.dart';
import 'package:aldurar_alnaqia/models/consts/tareeqa_bios_collection.dart';
import 'package:aldurar_alnaqia/models/consts/ibn_ata_allah.dart';
import 'package:aldurar_alnaqia/models/consts/khitam_alsalah_collection.dart';

/// How a zikr's body is rendered.
///
/// Most azkar are plain [text]. Two compositions have bundled PDF content
/// and get dedicated viewers instead of the generic text renderer.
enum ZikrKind {
  text,
  hilyaNasab,
  tareeqaSanad,
}

class Zikr {
  /// Stable ASCII identifier. Never shown to users; used for routes,
  /// bookmarks, downloads and filenames. Never rename.
  final String id;
  final String title;
  final String content;
  final String notes;
  final String footer;
  final String? url;
  final ZikrKind kind;

  const Zikr({
    required this.id,
    required this.title,
    required this.content,
    this.url,
    this.notes = '',
    this.footer = '',
    this.kind = ZikrKind.text,
  });

  bool get hasAudio => url != null && url!.isNotEmpty;
}

/// A named grouping shown as one tile in the awrad list.
class ZikrCollection {
  /// Stable ASCII identifier for routes/bookmarks. Never rename.
  final String id;
  final String title;
  final List<Zikr> items;

  const ZikrCollection({
    required this.id,
    required this.title,
    required this.items,
  });

  List<String> get zikrIds => [for (final z in items) z.id];
}

/// The single source of truth for grouping. To add a new zikr:
/// 1. define `const ... = Zikr(id: '...', ...)` in `consts/`,
/// 2. add it to its collection list (or [orphanZikrs]).
/// Search, audio sections, week wird and lookups all derive from here.
const allCollections = <ZikrCollection>[
  ZikrCollection(
      id: 'hadra', title: 'الحضرة الصديقية', items: alhadraCollection,),
  ZikrCollection(
      id: 'yousria',
      title: 'الصلوات اليسرية',
      items: salawatYousriaCollection,),
  ZikrCollection(
      id: 'dalayil', title: 'دلائل الخيرات', items: dalayilAlkhayratCollection,),
  ZikrCollection(
      id: 'khitam',
      title: 'أوراد ختام الصلاة',
      items: khitamAlSalahCollection,),
  ZikrCollection(
      id: 'gomari',
      title: 'أوراد سيدي عبد الله بن الصديق الغماري',
      items: azkarAlgomariCollection,),
  ZikrCollection(id: 'ahzab', title: 'الأحزاب', items: ahzabCollection),
  ZikrCollection(id: 'qasaed', title: 'قصائد', items: poemsCollection),
  ZikrCollection(
      id: 'salawat-mukhtara',
      title: 'صلوات مختارة على النبي ﷺ',
      items: chosenSalawatCollection,),
  ZikrCollection(
      id: 'ibn-ata-allah',
      title: 'أوراد سيدي ابن عطاء الله',
      items: ibnAtaAllahCollection,),
  ZikrCollection(
      id: 'tarajem',
      title: 'تراجم رجال الطريقة',
      items: tareeqaBiosCollection,),
];

/// Azkar that belong to no collection (shown as individual tiles).
const orphanZikrs = <Zikr>[
  asrGomaa,
  adabAltareeqa,
  waseyaGamea,
  sanadAltareeqa,
];

/// Day-wird pseudo-bookmarks (listings, not azkar).
const weekCollectionBookmarkId = 'week-collection';
String dayWirdBookmarkId(int day) => 'day-wird-$day';

/// Canonical day-wird display titles (1 = Monday .. 7 = Sunday).
const dayWirdTitles = <int, String>{
  1: 'ورد يوم الإثنين',
  2: 'ورد يوم الثلاثاء',
  3: 'ورد يوم الأربعاء',
  4: 'ورد يوم الخميس',
  5: 'ورد يوم الجمعة',
  6: 'ورد يوم السبت',
  7: 'ورد يوم الأحد',
};

// ---------------------------------------------------------------------------
// Derived registries (no manual per-zikr maps)
// ---------------------------------------------------------------------------

Map<String, Zikr> _buildZikrById() {
  final map = <String, Zikr>{};
  for (final c in allCollections) {
    for (final z in c.items) {
      map.putIfAbsent(z.id, () => z);
    }
  }
  // Morning/evening items that live in no displayed collection
  // (wazifa, musabbaat, asas) still need registration.
  for (final z in morningEveningAzkarCollection) {
    map.putIfAbsent(z.id, () => z);
  }
  for (final z in orphanZikrs) {
    map.putIfAbsent(z.id, () => z);
  }
  return map;
}

final zikrById = _buildZikrById();

/// First-registered zikr wins on duplicate display titles.
final zikrByTitle = _buildZikrByTitle();

Map<String, Zikr> _buildZikrByTitle() {
  final map = <String, Zikr>{};
  for (final z in zikrById.values) {
    map.putIfAbsent(z.title, () => z);
  }
  return map;
}

final collectionById = <String, ZikrCollection>{
  for (final c in allCollections) c.id: c,
};

final collectionByTitle = <String, ZikrCollection>{
  for (final c in allCollections) c.title: c,
};

/// Resolves a stable id or a display title (search suggestions are titles).
/// Returns null when unknown.
Zikr? resolveZikr(String idOrTitle) =>
    zikrById[idOrTitle] ?? zikrByTitle[idOrTitle];

/// Display title for an id (unknown strings pass through).
String zikrTitleOf(String idOrTitle) =>
    resolveZikr(idOrTitle)?.title ?? idOrTitle;

ZikrCollection? resolveCollection(String idOrTitle) =>
    collectionById[idOrTitle] ?? collectionByTitle[idOrTitle];

/// Zikr ids of a collection (accepts id or title).
List<String> collectionZikrIds(String collectionIdOrTitle) {
  final c = resolveCollection(collectionIdOrTitle);
  if (c == null) return const [];
  return c.zikrIds;
}

/// Ordered, de-duplicated display titles for search suggestions.
List<String> allZikrTitles() =>
    {for (final z in zikrById.values) z.title}.toList();

// ---------------------------------------------------------------------------
// Audio sections (derived compositions, single place to edit)
// ---------------------------------------------------------------------------

class AudioSection {
  final String id;
  final String title;
  final List<Zikr> items;

  const AudioSection({
    required this.id,
    required this.title,
    required this.items,
  });

  List<Zikr> get withAudio => items.where((z) => z.hasAudio).toList();
}

final audioSections = <AudioSection>[
  const AudioSection(
      id: 'dalayil', title: 'دلائل الخيرات', items: dalayilAlkhayratCollection,),
  const AudioSection(
    id: 'yousria-days',
    title: 'الصلوات اليسرية',
    items: [
      day1Yousria,
      day2Yousria,
      day3Yousria,
      day4Yousria,
      day5Yousria,
      day6Yousria,
    ],
  ),
  const AudioSection(
    id: 'ahzab',
    title: 'الأحزاب',
    items: [...ahzabCollection, alfathAlsedeqy],
  ),
  AudioSection(
    id: 'qasaed',
    title: 'قصائد',
    // dua-istighatha is a dua read with the wazifa, not a qasida.
    items: [
      for (final z in poemsCollection)
        if (z.id != 'dua-istighatha') z,
    ],
  ),
  const AudioSection(
      id: 'hadra', title: 'الحضرة الصديقية', items: alhadraCollection,),
  const AudioSection(
      id: 'salawat-mukhtara',
      title: 'صلوات مختارة على النبي ﷺ',
      items: chosenSalawatCollection,),
  const AudioSection(
      id: 'ibn-ata-allah',
      title: 'أوراد سيدي ابن عطاء الله',
      items: ibnAtaAllahCollection,),
  const AudioSection(
    id: 'daily',
    title: 'أوراد يومية',
    items: [
      alwazifaZarouquia,
      almusabaeat,
      alasas,
      alhyliaAndNasab,
    ],
  ),
  const AudioSection(
      id: 'asr-jumua', title: 'ورد عصر يوم الجمعة', items: [asrGomaa],),
];
