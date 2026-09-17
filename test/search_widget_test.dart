import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/widgets/search_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('filterAndRankSuggestions', () {
    test('puts the dedicated ahzab before Dalail from the first letter', () {
      for (final query in ['ح', 'حز', 'حزب']) {
        final results = filterAndRankSuggestions(query, allZikrTitles());

        expect(
          results.take(5).toList(),
          orderedEquals([
            'حزب البحر',
            'حزب البر (الحزب الكبير)',
            'حزب النصر',
            'حزب الإمام النووي',
            'حزب الفتح الصديقي',
          ]),
          reason: 'query: $query',
        );
        expect(results[5], 'الحزب الأول ورد يوم الاثنين');
      }
    });

    test('finds both poems from every prefix of burda', () {
      for (final query in [
        'ب',
        'بر',
        'برد',
        'بردة',
        'ا',
        'ال',
        'الب',
        'البر',
        'البرد',
        'البردة',
      ]) {
        final results = filterAndRankSuggestions(query, allZikrTitles());

        expect(
          results.take(2).toList(),
          orderedEquals(['قصيدة بانت سعاد', 'بردة الإمام البوصيري']),
          reason: 'query: $query',
        );
      }
    });

    test('keeps literal matches in their original order otherwise', () {
      expect(
        filterAndRankSuggestions('الأحد', [
          'الحزب السابع ورد يوم الأحد',
          'ورد يوم الأحد',
        ]),
        orderedEquals(['الحزب السابع ورد يوم الأحد', 'ورد يوم الأحد']),
      );
    });
  });
}
