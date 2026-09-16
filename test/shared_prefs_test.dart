import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/prayer_schedule.dart'
    show PrayerHighLatitudeRules, PrayerMadhabs, PrayerMethods;
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferencesService().init();
  });

  group('theme mode storage', () {
    test('absent value defaults to system', () {
      expect(SharedPreferencesService.getThemeMode(), 'system');
    });

    test('round-trips valid values', () async {
      for (final mode in ['light', 'dark', 'system']) {
        await SharedPreferencesService.setThemeMode(mode);
        expect(SharedPreferencesService.getThemeMode(), mode);
      }
    });

    test('unknown value resets to system', () {
      SharedPreferences.setMockInitialValues(
        <String, Object>{'theme_mode': 'neon'},
      );
      return SharedPreferencesService().init().then((_) {
        expect(SharedPreferencesService.getThemeMode(), 'system');
      });
    });
  });

  group('font size storage', () {
    test('absent value defaults to 22', () {
      expect(SharedPreferencesService.getFontSize(), 22);
    });

    test('round-trips a valid size', () {
      SharedPreferencesService.setFontSize(28);
      expect(SharedPreferencesService.getFontSize(), 28);
    });

    test('out-of-range values reset to default', () {
      SharedPreferencesService.setFontSize(15);
      expect(SharedPreferencesService.getFontSize(), 22);
      SharedPreferencesService.setFontSize(100);
      expect(SharedPreferencesService.getFontSize(), 22);
    });
  });

  group('hijri offset storage', () {
    test('absent value defaults to 0', () {
      expect(SharedPreferencesService.getHijriDayOffset(), 0);
    });

    test('round-trips the valid range', () {
      for (var offset = -2; offset <= 2; offset++) {
        SharedPreferencesService.setHijriDayOffset(offset);
        expect(SharedPreferencesService.getHijriDayOffset(), offset);
      }
    });

    test('out-of-range values reset to 0', () {
      SharedPreferencesService.setHijriDayOffset(3);
      expect(SharedPreferencesService.getHijriDayOffset(), 0);
      SharedPreferencesService.setHijriDayOffset(-3);
      expect(SharedPreferencesService.getHijriDayOffset(), 0);
    });
  });

  group('file open action storage', () {
    test('absent value defaults to ask', () {
      expect(SharedPreferencesService.getFileOpenAction(), 'ask');
    });

    test('unknown value resets to ask', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{'file_open_action': 'stream'},
      );
      await SharedPreferencesService().init();
      expect(SharedPreferencesService.getFileOpenAction(), 'ask');
    });
  });

  group('prayer settings storage', () {
    test('absent values yield app defaults', () {
      expect(SharedPreferencesService.getMethod(), PrayerMethods.egyptian);
      expect(SharedPreferencesService.getAsrCalculation(), PrayerMadhabs.shafi);
      expect(
        SharedPreferencesService.getHighLatitudeRule(),
        PrayerHighLatitudeRules.middleOfNight,
      );
      expect(SharedPreferencesService.getTimezone(), isEmpty);
      expect(SharedPreferencesService.getLatitude(), 0.0);
      expect(SharedPreferencesService.getLongitude(), 0.0);
    });

    test('unknown method/madhab/rule reset to defaults', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'method': 'bogus',
        'asrCalculation': 'bogus',
        'highLatitudeRule': 'bogus',
      });
      await SharedPreferencesService().init();
      expect(SharedPreferencesService.getMethod(), PrayerMethods.egyptian);
      expect(SharedPreferencesService.getAsrCalculation(), PrayerMadhabs.shafi);
      expect(
        SharedPreferencesService.getHighLatitudeRule(),
        PrayerHighLatitudeRules.middleOfNight,
      );
    });
  });

  group('bookmarks storage', () {
    test('starts empty', () {
      expect(SharedPreferencesService.getBookmarks(), isEmpty);
    });

    test('add ignores duplicates, remove drops the entry', () {
      SharedPreferencesService.addBookmark('a');
      SharedPreferencesService.addBookmark('a');
      expect(SharedPreferencesService.getBookmarks(), ['a']);
      SharedPreferencesService.addBookmark('b');
      SharedPreferencesService.removeBookmark('a');
      expect(SharedPreferencesService.getBookmarks(), ['b']);
    });

    test('removing a missing entry is a no-op', () {
      SharedPreferencesService.removeBookmark('ghost');
      expect(SharedPreferencesService.getBookmarks(), isEmpty);
    });

    test('removeAllBookmarks clears everything', () {
      SharedPreferencesService.addBookmark('a');
      SharedPreferencesService.removeAllBookmarks();
      expect(SharedPreferencesService.getBookmarks(), isEmpty);
    });
  });

  group('yousria storage', () {
    test('banner starts undismissed and round-trips', () async {
      expect(SharedPreferencesService.getYousriaBannerDismissed(), isFalse);
      await SharedPreferencesService.setYousriaBannerDismissed(true);
      expect(SharedPreferencesService.getYousriaBannerDismissed(), isTrue);
    });

    test('beginning truncates to midnight', () {
      final noisy = DateTime(2024, 6, 15, 23, 59, 59);
      SharedPreferencesService.setYousriaBeginning(noisy);
      expect(
        SharedPreferencesService.getYousriaBeginning(),
        DateTime(2024, 6, 15),
      );
    });

    test('corrupt beginning resets to today', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{'yousriaStartingDay': 'not-a-date'},
      );
      await SharedPreferencesService().init();
      final now = DateTime.now();
      expect(
        SharedPreferencesService.getYousriaBeginning(),
        DateTime(now.year, now.month, now.day),
      );
    });
  });

  group('pdf last page storage', () {
    test('absent page is null and round-trips per title', () async {
      expect(SharedPreferencesService.getPdfLastPage('burda'), isNull);
      await SharedPreferencesService.setPdfLastPage('burda', 42);
      expect(SharedPreferencesService.getPdfLastPage('burda'), 42);
      expect(SharedPreferencesService.getPdfLastPage('other'), isNull);
    });
  });
}
