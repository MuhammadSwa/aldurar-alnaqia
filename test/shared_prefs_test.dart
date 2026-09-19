import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart'
    show PrayerHighLatitudeRules, PrayerMadhabs, PrayerMethods;
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cairo = City(
  nameEn: 'Cairo',
  nameAr: 'القاهرة',
  countryCode: 'EG',
  latitude: 30.0444,
  longitude: 31.2357,
  timeZone: 'Africa/Cairo',
);

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

  group('city storage', () {
    test('absent city is null', () {
      expect(SharedPreferencesService.getCity(), isNull);
    });

    test('setCity/getCity round-trips names; coords come from keys', () async {
      await SharedPreferencesService.savePrayerSettings(
        latitude: 30.05,
        longitude: 31.24,
        method: PrayerMethods.egyptian,
        asrCalculation: PrayerMadhabs.shafi,
        timezone: 'Africa/Cairo',
        city: _cairo,
      );
      final city = SharedPreferencesService.getCity();
      expect(city, isNotNull);
      expect(city!.nameEn, 'Cairo');
      expect(city.nameAr, 'القاهرة');
      expect(city.countryCode, 'EG');
      // Stored cityInfo keeps names only; coordinates stay in their keys.
      expect(city.latitude, 30.05);
      expect(city.longitude, 31.24);
    });

    test('setCity(null) clears a GPS-picked city', () async {
      await SharedPreferencesService.savePrayerSettings(
        latitude: 30.05,
        longitude: 31.24,
        method: PrayerMethods.egyptian,
        asrCalculation: PrayerMadhabs.shafi,
        timezone: 'Africa/Cairo',
        city: _cairo,
      );
      expect(SharedPreferencesService.getCity(), isNotNull);
      SharedPreferencesService.setCity(null);
      expect(SharedPreferencesService.getCity(), isNull);
      // Coordinates are untouched by clearing the city.
      expect(SharedPreferencesService.getLatitude(), 30.05);
    });

    test('(0, 0) coordinates mean no city even with stored info', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'cityInfo': '{"en":"Cairo","ar":"القاهرة","country":"EG"}',
      });
      await SharedPreferencesService().init();
      expect(SharedPreferencesService.getCity(), isNull);
    });

    test('corrupt city info is dropped and returns null', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'cityInfo': 'not-json',
        'latitude': 30.0,
        'longitude': 31.0,
      });
      await SharedPreferencesService().init();
      expect(SharedPreferencesService.getCity(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cityInfo'), isNull);
    });
  });

  group('savePrayerSettings/loadPrayerSettings', () {
    test('saves interdependent settings together', () async {
      await SharedPreferencesService.savePrayerSettings(
        latitude: 21.4225,
        longitude: 39.8262,
        method: PrayerMethods.ummAlQura,
        asrCalculation: PrayerMadhabs.hanafi,
        timezone: 'Asia/Riyadh',
        highLatitudeRule: PrayerHighLatitudeRules.seventhOfNight,
      );
      final loaded =
          SharedPreferencesService.loadPrayerSettings();
      expect(loaded.latitude, 21.4225);
      expect(loaded.longitude, 39.8262);
      expect(loaded.method, PrayerMethods.ummAlQura);
      expect(loaded.madhab, PrayerMadhabs.hanafi);
      expect(
        loaded.highLatitudeRule,
        PrayerHighLatitudeRules.seventhOfNight,
      );
      expect(loaded.timezone, 'Asia/Riyadh');
    });

    test('null highLatitudeRule leaves the stored rule unchanged', () async {
      await SharedPreferencesService.savePrayerSettings(
        latitude: 30.04,
        longitude: 31.23,
        method: PrayerMethods.egyptian,
        asrCalculation: PrayerMadhabs.shafi,
        timezone: 'Africa/Cairo',
        highLatitudeRule: PrayerHighLatitudeRules.seventhOfNight,
      );
      await SharedPreferencesService.savePrayerSettings(
        latitude: 30.04,
        longitude: 31.23,
        method: PrayerMethods.egyptian,
        asrCalculation: PrayerMadhabs.shafi,
        timezone: 'Africa/Cairo',
      );
      expect(
        SharedPreferencesService.getHighLatitudeRule(),
        PrayerHighLatitudeRules.seventhOfNight,
      );
    });

    test('hijri offset does not leak into solar settings', () {
      final before = SharedPreferencesService.loadPrayerSettings().fingerprint;
      SharedPreferencesService.setHijriDayOffset(1);
      // The offset lives in prefs and the native payload (as a build
      // parameter), never in the calculation inputs or their cache key.
      expect(
        SharedPreferencesService.loadPrayerSettings().fingerprint,
        before,
      );
      expect(SharedPreferencesService.getHijriDayOffset(), 1);
    });
  });

  group('initialization guard', () {
    test('reads and writes throw before init instead of silently no-op', () {
      SharedPreferencesService.resetForTest();
      expect(SharedPreferencesService.isInitialized, isFalse);
      expect(SharedPreferencesService.getFontSize, throwsStateError);
      expect(SharedPreferencesService.getBookmarks, throwsStateError);
      expect(
        () => SharedPreferencesService.setFontSize(28),
        throwsStateError,
      );
      expect(
        SharedPreferencesService.loadPrayerSettings,
        throwsStateError,
      );
    });

    test('focused stores are reachable from the instance', () {
      expect(SharedPreferencesService.isInitialized, isTrue);
      expect(SharedPreferencesService.instance.appearance.getFontSize(), 22);
      expect(SharedPreferencesService.instance.bookmarks.getBookmarks(), isEmpty);
    });
  });

  group('prayer city label storage', () {
    test('absent label is empty', () {
      expect(SharedPreferencesService.getPrayerCityLabel(), isEmpty);
    });

    test('label round-trips through savePrayerSettings', () async {
      await SharedPreferencesService.savePrayerSettings(
        latitude: 30.0444,
        longitude: 31.2357,
        method: PrayerMethods.egyptian,
        asrCalculation: PrayerMadhabs.shafi,
        timezone: 'Africa/Cairo',
        cityLabel: 'القاهرة، مصر',
      );
      expect(
        SharedPreferencesService.getPrayerCityLabel(),
        'القاهرة، مصر',
      );
    });

    test('savePrayerSettings stores the label with the settings', () async {
      await SharedPreferencesService.savePrayerSettings(
        latitude: 30.0444,
        longitude: 31.2357,
        method: PrayerMethods.egyptian,
        asrCalculation: PrayerMadhabs.shafi,
        timezone: 'Africa/Cairo',
        city: _cairo,
        cityLabel: 'القاهرة، مصر',
      );
      expect(
        SharedPreferencesService.getPrayerCityLabel(),
        'القاهرة، مصر',
      );
    });

    test('null cityLabel leaves the stored label unchanged', () async {
      await SharedPreferencesService.savePrayerSettings(
        latitude: 30.0444,
        longitude: 31.2357,
        method: PrayerMethods.egyptian,
        asrCalculation: PrayerMadhabs.shafi,
        timezone: 'Africa/Cairo',
        city: _cairo,
        cityLabel: 'القاهرة، مصر',
      );
      await SharedPreferencesService.savePrayerSettings(
        latitude: 30.05,
        longitude: 31.24,
        method: PrayerMethods.egyptian,
        asrCalculation: PrayerMadhabs.shafi,
        timezone: 'Africa/Cairo',
      );
      expect(
        SharedPreferencesService.getPrayerCityLabel(),
        'القاهرة، مصر',
      );
      expect(SharedPreferencesService.getCity(), isNull);
    });
  });
}
