import 'package:aldurar_alnaqia/screens/zikr_screen/zikr_blocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseZikrBlocks', () {
    test('splits sadr and ajz on the bayt separator', () {
      final blocks = parseZikrBlocks('صدر البيت __ عجز البيت');

      expect(blocks, hasLength(1));
      final bayt = blocks.single as BaytBlock;
      expect(bayt.sadr, 'صدر البيت');
      expect(bayt.ajz, 'عجز البيت');
    });

    test('trims whitespace around hemistichs', () {
      final blocks =
          parseZikrBlocks('  فِي كُلِّ فَاتِحَةٍ   __   حُقَّ الثَّنَاءُ  ');

      final bayt = blocks.single as BaytBlock;
      expect(bayt.sadr, 'فِي كُلِّ فَاتِحَةٍ');
      expect(bayt.ajz, 'حُقَّ الثَّنَاءُ');
    });

    test('keeps footnote markers inside hemistichs', () {
      final blocks = parseZikrBlocks(
          'عَزَّتْ شَرِيعَتُهُ[^1] الْبَيْضَاءُ حِينَ أَتَى __ أَحْقَافَ بَدْرٍ');

      final bayt = blocks.single as BaytBlock;
      expect(bayt.sadr, contains('[^1]'));
    });

    test('parses ## lines as headings without the markers', () {
      final blocks = parseZikrBlocks('## الفصل الأول (في الغزل)');

      expect(blocks, hasLength(1));
      final heading = blocks.single as HeadingBlock;
      expect(heading.text, 'الفصل الأول (في الغزل)');
    });

    test('groups consecutive prose lines and splits on blank lines', () {
      final blocks = parseZikrBlocks('سطر أول\nسطر ثان\n\nسطر ثالث');

      expect(blocks, hasLength(2));
      expect((blocks[0] as ProseBlock).text, 'سطر أول\nسطر ثان');
      expect((blocks[1] as ProseBlock).text, 'سطر ثالث');
    });

    test('mixes headings, bayts and prose in order', () {
      final blocks = parseZikrBlocks(
        '## الفصل الأول\n'
        'صدر __ عجز\n'
        '\n'
        'دعاء ختامي',
      );

      expect(blocks, hasLength(3));
      expect(blocks[0], isA<HeadingBlock>());
      expect(blocks[1], isA<BaytBlock>());
      expect(blocks[2], isA<ProseBlock>());
    });

    test('malformed bayt lines fall back to prose', () {
      // Empty ajz.
      expect(parseZikrBlocks('صدر فقط __').single, isA<ProseBlock>());
      // Two separators.
      expect(parseZikrBlocks('أ __ ب __ ج').single, isA<ProseBlock>());
    });

    test('ignores blank lines and trims indentation', () {
      final blocks = parseZikrBlocks('\n\n      وسعهُ عِلمُ الله\n\n');

      expect(blocks, hasLength(1));
      expect((blocks.single as ProseBlock).text, 'وسعهُ عِلمُ الله');
    });

    test('parses a real poem sample', () {
      final blocks = parseZikrBlocks(
        'فِي كُـلِّ فَاتِحَةٍ لِلْقَوْلِ مُعْتبِرَهْ __ حُقَّ الثَّنَاءُ عَلَى الْمَبْعُوثِ بِالْبَقَرَهْ\n'
        'فِي آلِ عِمْرَانَ قِدَمًا شَاعَ مَبْعَثُهُ __ رِجَالُهُمُ والنِّسَاءُ اسْتَوْضَحُواْ خَبَرَهْ',
      );

      expect(blocks, hasLength(2));
      expect(blocks[0], isA<BaytBlock>());
      expect(blocks[1], isA<BaytBlock>());
      expect((blocks[0] as BaytBlock).sadr,
          'فِي كُـلِّ فَاتِحَةٍ لِلْقَوْلِ مُعْتبِرَهْ');
    });

    test('print hijri date', () {
      final h = HijriCalendar.fromDate(DateTime.now());
      print('=== DART HIJRI: ${h.hDay} / ${h.hMonth} / ${h.hYear} ===');
    });
  });
}
