import 'package:flutter_test/flutter_test.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/models/consts/chosen_salawat.dart';
import 'package:aldurar_alnaqia/models/consts/salawat_yousria_collection.dart';
import 'package:aldurar_alnaqia/models/week_collection_data.dart';

void main() {
  group('zikr registry', () {
    test('every id is unique and ASCII-safe', () {
      final ids = zikrById.keys.toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(id, matches(RegExp(r'^[a-z0-9-]+$')), reason: 'id: $id');
      }
    });

    test('every collection item is registered', () {
      for (final c in allCollections) {
        for (final z in c.items) {
          expect(zikrById[z.id], same(z), reason: 'unregistered: ${z.id}');
        }
      }
      for (final z in orphanZikrs) {
        expect(zikrById[z.id], same(z), reason: 'unregistered: ${z.id}');
      }
    });

    test('collection ids are unique and ASCII-safe', () {
      final ids = allCollections.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(id, matches(RegExp(r'^[a-z0-9-]+$')));
      }
    });

    test('legacy titles resolve to stable ids', () {
      expect(resolveZikr('ورد الأساس')?.id, 'wird-asas');
      expect(resolveZikr('wird-asas')?.id, 'wird-asas');
      expect(resolveCollection('قصائد')?.id, 'qasaed');
      // Legacy typo for the gomari collection.
      expect(
        resolveCollection('أوارد سيدي عبد الله بن الصديق الغماري')?.id,
        isNull,
      );
      expect(migrateBookmark('أوارد سيدي عبد الله بن الصديق الغماري'),
          'gomari');
    });

    test('duplicate hilya title resolves to the canonical audio entry', () {
      final zikr = resolveZikr('الحلية والنسب النبوي الشريف');
      expect(zikr?.id, 'hilya-nasab');
      expect(zikr?.hasAudio, isTrue);
    });

    test('bookmark migration covers day wirds and week collection', () {
      expect(migrateBookmark('ورد يوم الإثنين'), 'day-wird-1');
      expect(migrateBookmark('ورد يوم الأحد'), 'day-wird-7');
      expect(migrateBookmark('أوراد الأسبوع'), 'week-collection');
      expect(migrateBookmark('day-wird-3'), 'day-wird-3');
      expect(migrateBookmark('qasaed'), 'qasaed');
    });

    test('week wird ids all resolve', () {
      for (var day = 1; day <= 7; day++) {
        for (final id in WeekCollectionAzkar.getDay(day, isToday: true)) {
          expect(resolveZikr(id), isNotNull, reason: 'day $day: $id');
        }
        for (final id in WeekCollectionAzkar.getDay(day, isToday: false)) {
          expect(resolveZikr(id), isNotNull, reason: 'day $day: $id');
        }
      }
    });

    test('audio sections only list items with audio', () {
      expect(audioSections, isNotEmpty);
      for (final section in audioSections) {
        for (final z in section.withAudio) {
          expect(z.hasAudio, isTrue);
        }
      }
      final total = audioSections.fold<int>(
          0, (sum, s) => sum + s.withAudio.length);
      expect(total, greaterThan(0));
    });

    test('search suggestions cover every zikr', () {
      final titles = allZikrTitles();
      expect(titles.length, zikrByTitle.length);
      for (final z in zikrById.values) {
        expect(titles, contains(z.title));
      }
    });

    test('yousria day lookup matches explicit day list', () {
      expect(yousriaDayZikrs, hasLength(6));
      for (var day = 1; day <= 6; day++) {
        expect(yousriaDayZikr(day), same(yousriaDayZikrs[day - 1]));
        expect(yousriaDayZikr(day).id, isNotEmpty);
      }
    });

    test('wednesday wird tracks chosen-salawat collection order', () {
      final wednesday = WeekCollectionAzkar.collection[2];
      expect(
        wednesday,
        ['manzuma-asma-husna', for (final z in chosenSalawatCollection) z.id],
      );
    });

    test('qasaed audio excludes dua-istighatha by id, not position', () {
      final qasaed = audioSections.firstWhere((s) => s.id == 'qasaed');
      expect(qasaed.items.map((z) => z.id), isNot(contains('dua-istighatha')));
      for (final z in qasaed.items) {
        expect(resolveZikr(z.id), isNotNull);
      }
    });
  });
}
