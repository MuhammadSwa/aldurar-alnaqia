import 'package:aldurar_alnaqia/common/helpers/arabic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeArabic', () {
    test('unifies hamza variants to bare alef', () {
      expect(normalizeArabic('أحمد'), normalizeArabic('احمد'));
      expect(normalizeArabic('إسلام'), normalizeArabic('اسلام'));
      expect(normalizeArabic('آية'), normalizeArabic('ايه'));
      expect(normalizeArabic('ٱلحمد'), normalizeArabic('الحمد'));
    });

    test('unifies ta-marbuta and alef-maqsura spellings', () {
      expect(normalizeArabic('الاسكندريه'), normalizeArabic('الإسكندرية'));
      expect(normalizeArabic('صلاة'), normalizeArabic('صلاه'));
      expect(normalizeArabic('مصطفى'), normalizeArabic('مصطفي'));
    });

    test('maps hamza-on-letter to its carrier', () {
      expect(normalizeArabic('مؤمن'), normalizeArabic('مومن'));
      expect(normalizeArabic('قارئ'), normalizeArabic('قاري'));
    });

    test('strips diacritics and tatweel', () {
      expect(normalizeArabic('بِسْمِ اللَّهِ'), 'بسم الله');
      expect(normalizeArabic('صــلاة'), normalizeArabic('صلاة'));
    });

    test('lowercases latin and collapses whitespace', () {
      expect(normalizeArabic('  Cairo  Bank  '), 'cairo bank');
      expect(normalizeArabic('New\nYork'), 'new york');
    });

    test('empty input stays empty', () {
      expect(normalizeArabic(''), isEmpty);
      expect(normalizeArabic('   '), isEmpty);
    });
  });
}
