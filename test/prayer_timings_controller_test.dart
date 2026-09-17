import 'package:aldurar_alnaqia/screens/prayer_timings_screen/city_directory.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/prayer_schedule.dart'
    show PrayerMadhabs, PrayerMethods;
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

const _cairo = City(
  nameEn: 'Cairo',
  nameAr: 'القاهرة',
  countryCode: 'EG',
  latitude: 30.0444,
  longitude: 31.2357,
  timeZone: 'Africa/Cairo',
);

const _chicago = City(
  nameEn: 'Chicago',
  nameAr: null,
  countryCode: 'US',
  latitude: 41.8781,
  longitude: -87.6298,
  timeZone: 'America/Chicago',
);

CityDirectory _testDirectory() => CityDirectory(
      cities: const [_cairo, _chicago],
      countries: const {
        'EG': CountryInfo(code: 'EG', nameAr: 'مصر', nameEn: 'Egypt'),
        'US': CountryInfo(code: 'US', nameAr: null, nameEn: 'United States'),
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Swallow the native prayer-notification channel: every settings save
  // triggers a refresh over it, and there is no native host in tests.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('app/prayer_notification'),
    (MethodCall call) async => null,
  );

  setUpAll(tzdata.initializeTimeZones);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferencesService().init();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        cityDirectoryProvider.overrideWith((ref) async => _testDirectory()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settleInit() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  group('PrayerTimingsNotifier init', () {
    test('unconfigured prefs stay uninitialized-safe with empty state',
        () async {
      final container = makeContainer();
      container.read(prayerProvider);
      await settleInit();

      final state = container.read(prayerProvider);
      expect(state.isInitialized, isTrue);
      expect(state.schedule, isNull);
      expect(state.cityLabel, isEmpty);
      expect(state.nextPrayerInfo.$1, isNull);
      expect(state.nextPrayerInfo.$2, isEmpty);
      expect(state.islamicWeekday, inInclusiveRange(1, 7));
    });
  });

  group('PrayerTimingsNotifier.setPrayerSettings', () {
    test('city pick saves settings, schedule, and exact label', () async {
      final container = makeContainer();
      final notifier = container.read(prayerProvider.notifier);

      await notifier.setPrayerSettings(
        lat: 30.0444,
        long: 31.2357,
        method: PrayerMethods.egyptian,
        asrCalc: PrayerMadhabs.shafi,
        city: _cairo,
      );

      final state = container.read(prayerProvider);
      expect(state.schedule, isNotNull);
      expect(state.cityLabel, 'القاهرة، مصر');
      expect(state.nextPrayerInfo.$1, isNotNull);
      expect(state.nextPrayerInfo.$2, isNotEmpty);
      expect(SharedPreferencesService.getTimezone(), 'Africa/Cairo');
      expect(SharedPreferencesService.getCity()?.nameEn, 'Cairo');
    });

    test('GPS near a city labels it without storing cityInfo', () async {
      final container = makeContainer();
      final notifier = container.read(prayerProvider.notifier);

      await notifier.setPrayerSettings(
        lat: 30.05,
        long: 31.24,
        method: PrayerMethods.egyptian,
        asrCalc: PrayerMadhabs.shafi,
      );

      expect(container.read(prayerProvider).cityLabel, 'القاهرة، مصر');
      expect(SharedPreferencesService.getCity(), isNull);
      expect(SharedPreferencesService.getTimezone(), 'Africa/Cairo');
    });

    test('GPS far from any city falls back to coordinates', () async {
      final container = makeContainer();
      final notifier = container.read(prayerProvider.notifier);

      await notifier.setPrayerSettings(
        lat: 0,
        long: -140,
        method: PrayerMethods.egyptian,
        asrCalc: PrayerMadhabs.shafi,
      );

      final state = container.read(prayerProvider);
      // Label is capped at 50 km, but timezone resolution is uncapped.
      expect(state.cityLabel, '0.00°، -140.00°');
      expect(state.schedule, isNotNull);
      expect(SharedPreferencesService.getTimezone(), isNotEmpty);
    });

    test('unresolvable coordinates save nothing', () async {
      final container = makeContainer();
      final notifier = container.read(prayerProvider.notifier);

      await notifier.setPrayerSettings(
        lat: 91,
        long: 31.24,
        method: PrayerMethods.egyptian,
        asrCalc: PrayerMadhabs.shafi,
      );

      expect(SharedPreferencesService.getLatitude(), 0.0);
      expect(SharedPreferencesService.getTimezone(), isEmpty);
      expect(container.read(prayerProvider).schedule, isNull);
    });

    test('legacy installs fall back to the stored city name', () async {
      // Saved before labels existed: cityInfo present, cityLabel empty.
      await SharedPreferencesService.savePrayerSettings(
        latitude: 30.0444,
        longitude: 31.2357,
        method: PrayerMethods.egyptian,
        asrCalculation: PrayerMadhabs.shafi,
        timezone: 'Africa/Cairo',
        city: _cairo,
      );
      expect(SharedPreferencesService.getPrayerCityLabel(), isEmpty);

      final container = makeContainer();
      container.read(prayerProvider);
      await settleInit();

      expect(container.read(prayerProvider).cityLabel, 'القاهرة');
    });
  });

  group('PrayerTimingsNotifier.refresh', () {
    test('no-ops when the next event is still in the future', () async {
      final container = makeContainer();
      final notifier = container.read(prayerProvider.notifier);
      await notifier.setPrayerSettings(
        lat: 30.0444,
        long: 31.2357,
        method: PrayerMethods.egyptian,
        asrCalc: PrayerMadhabs.shafi,
        city: _cairo,
      );

      final before = container.read(prayerProvider).nextPrayerInfo;
      notifier.refresh();
      expect(container.read(prayerProvider).nextPrayerInfo, before);
    });

    test('is safe to call after dispose', () async {
      final container = makeContainer();
      final notifier = container.read(prayerProvider.notifier);
      await settleInit();
      container.dispose();

      expect(notifier.refresh, returnsNormally);
    });
  });

  group('module functions', () {
    test('todayPrayerSchedule is null unconfigured, set when configured',
        () async {
      expect(todayPrayerSchedule(), isNull);

      await SharedPreferencesService.savePrayerSettings(
        latitude: 30.0444,
        longitude: 31.2357,
        method: PrayerMethods.egyptian,
        asrCalculation: PrayerMadhabs.shafi,
        timezone: 'Africa/Cairo',
        city: _cairo,
      );
      expect(todayPrayerSchedule(), isNotNull);
    });

    test('islamicWeekdayNow always returns a valid weekday', () async {
      expect(islamicWeekdayNow(), inInclusiveRange(1, 7));

      await SharedPreferencesService.savePrayerSettings(
        latitude: 30.0444,
        longitude: 31.2357,
        method: PrayerMethods.egyptian,
        asrCalculation: PrayerMadhabs.shafi,
        timezone: 'Africa/Cairo',
        city: _cairo,
      );
      expect(islamicWeekdayNow(), inInclusiveRange(1, 7));
    });
  });
}
