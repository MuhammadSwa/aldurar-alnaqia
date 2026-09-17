import 'package:aldurar_alnaqia/prayer/prayer_providers.dart';
import 'package:aldurar_alnaqia/prayer/prayer_repository.dart';
import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/city_directory.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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

const _settings = PrayerSettings(
  latitude: 30.0444,
  longitude: 31.2357,
  timezone: 'Africa/Cairo',
  method: 'egyptian',
  madhab: 'shafi',
  highLatitudeRule: 'middle_of_night',
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
  // pushes tables over it, and there is no native host in tests.
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
    return ProviderContainer(
      overrides: [
        cityDirectoryProvider.overrideWith((ref) async => _testDirectory()),
      ],
    );
  }

  /// A [WidgetRef] for calling [savePrayerSettings] in tests.
  Future<WidgetRef> harnessRef(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, r, _) {
            ref = r;
            return const SizedBox();
          },
        ),
      ),
    );
    return ref;
  }

  group('savePrayerSettings', () {
    testWidgets('city pick saves settings, label, and a derived view',
        (tester) async {
      final container = makeContainer();

      final saved = await savePrayerSettings(
        await harnessRef(tester, container),
        lat: 30.0444,
        long: 31.2357,
        method: PrayerMethods.egyptian,
        asrCalc: PrayerMadhabs.shafi,
        city: _cairo,
      );

      expect(saved, isTrue);
      expect(SharedPreferencesService.getTimezone(), 'Africa/Cairo');
      expect(SharedPreferencesService.getCity()?.nameEn, 'Cairo');
      // Providers publish without further calls.
      expect(
        container.read(prayerConfigProvider).settings.timezone,
        'Africa/Cairo',
      );
      expect(
        container.read(prayerConfigProvider).cityLabel,
        'القاهرة، مصر',
      );
      final view = container.read(prayerViewProvider);
      expect(view, isNotNull);
      expect(view!.next.time.isAfter(DateTime.now()), isTrue);
      // The boundary timer is app-lifecycle state: dispose the container
      // before the test ends so fake_async has no pending timers.
      container.dispose();
    });

    testWidgets('GPS near a city labels it without storing cityInfo',
        (tester) async {
      final container = makeContainer();

      final saved = await savePrayerSettings(
        await harnessRef(tester, container),
        lat: 30.05,
        long: 31.24,
        method: PrayerMethods.egyptian,
        asrCalc: PrayerMadhabs.shafi,
      );

      expect(saved, isTrue);
      expect(
        container.read(prayerConfigProvider).cityLabel,
        'القاهرة، مصر',
      );
      expect(SharedPreferencesService.getCity(), isNull);
      expect(container.read(prayerViewProvider), isNotNull);
      container.dispose();
    });

    testWidgets('unresolvable coordinates save nothing', (tester) async {
      final container = makeContainer();

      final saved = await savePrayerSettings(
        await harnessRef(tester, container),
        lat: 91,
        long: 31.24,
        method: PrayerMethods.egyptian,
        asrCalc: PrayerMadhabs.shafi,
      );

      expect(saved, isFalse);
      expect(SharedPreferencesService.getLatitude(), 0.0);
      expect(SharedPreferencesService.getTimezone(), isEmpty);
      expect(container.read(prayerViewProvider), isNull);
      container.dispose();
    });

    testWidgets('unconfigured prefs yield a null view (setup prompt)',
        (tester) async {
      final container = makeContainer();
      expect(container.read(prayerViewProvider), isNull);
      container.dispose();
    });
  });

  group('PrayerRepository derivation (no stored next)', () {
    test('backward clock jump flips Asr→Fajr with zero refresh calls', () {
      // The regression that motivated derive-don't-store: at 2:17pm the
      // next prayer is Asr; after setting the clock back to 2am the same
      // repository must report Fajr. No notifier, no refresh, no restart.
      final repo = PrayerRepository();
      final loc = tz.getLocation('Africa/Cairo');
      final afternoon = tz.TZDateTime(loc, 2024, 6, 15, 14, 17);
      final morning = tz.TZDateTime(loc, 2024, 6, 15, 2);

      final atAfternoon = repo.nextAt(_settings, afternoon);
      expect(atAfternoon, isNotNull);
      expect(atAfternoon!.id, PrayerEventId.asr);

      final atMorning = repo.nextAt(_settings, morning);
      expect(atMorning, isNotNull);
      expect(atMorning!.id, PrayerEventId.fajr);
    });

    test('after Isha the next event is tomorrow Fajr', () {
      final repo = PrayerRepository();
      final loc = tz.getLocation('Africa/Cairo');
      final night = tz.TZDateTime(loc, 2024, 6, 15, 23);
      final next = repo.nextAt(_settings, night)!;
      expect(next.id, PrayerEventId.fajr);
      expect(next.time.day, 16);
    });

    test('weekday flips at Maghrib, not midnight', () {
      final repo = PrayerRepository();
      final schedule = PrayerScheduleCalculator.calculate(
        settings: _settings,
        date: DateTime.utc(2024, 6, 15),
      )!;
      final maghrib = schedule.maghrib;
      expect(
        repo.weekdayAt(_settings, maghrib.subtract(const Duration(minutes: 1))),
        isNot(
          repo.weekdayAt(_settings, maghrib.add(const Duration(minutes: 1))),
        ),
      );
    });

    test('cache keys include settings: a method change recomputes', () {
      final repo = PrayerRepository();
      final loc = tz.getLocation('Africa/Cairo');
      final now = tz.TZDateTime(loc, 2024, 6, 15, 12);
      final a = repo.scheduleFor(_settings, now)!;
      expect(repo.cacheSize, 1);
      // Same fingerprint + day → identical instance (no recalculation).
      expect(identical(repo.scheduleFor(_settings, now), a), isTrue);
      final other = _settings.copyWith(method: PrayerMethods.karachi);
      final b = repo.scheduleFor(other, now)!;
      expect(identical(b, a), isFalse);
      expect(repo.cacheSize, 1, reason: 'old fingerprint entries are dropped');
    });

    test('invalid settings yield null, never throw', () {
      final repo = PrayerRepository();
      final bad = _settings.copyWith(timezone: '');
      expect(repo.scheduleFor(bad, DateTime.utc(2024, 6, 15)), isNull);
      expect(repo.nextAt(bad, DateTime.utc(2024, 6, 15)), isNull);
      expect(repo.nextBoundaryAt(bad, DateTime.utc(2024, 6, 15)), isNull);
    });

    test('nextBoundaryAt targets next event or midnight, plus 1s grace', () {
      final repo = PrayerRepository();
      final loc = tz.getLocation('Africa/Cairo');
      // Mid-afternoon: the next boundary is Asr (+1s).
      final afternoon = tz.TZDateTime(loc, 2024, 6, 15, 14, 17);
      final target = repo.nextBoundaryAt(_settings, afternoon)!;
      final asr = repo.nextAt(_settings, afternoon)!;
      expect(asr.id, PrayerEventId.asr);
      expect(
        target.millisecondsSinceEpoch,
        asr.time.millisecondsSinceEpoch + 1000,
      );
      // After Isha: midnight comes before tomorrow's Fajr.
      final night = tz.TZDateTime(loc, 2024, 6, 15, 23);
      final target2 = repo.nextBoundaryAt(_settings, night)!;
      expect(
        target2,
        tz.TZDateTime(loc, 2024, 6, 16).add(const Duration(seconds: 1)),
      );
    });
  });

  group('standalone helpers (routing, Yousria)', () {
    testWidgets('null unconfigured, set when configured', (tester) async {
      expect(todayPrayerSchedule(), isNull);
      expect(islamicWeekdayNow(), inInclusiveRange(1, 7));

      final container = makeContainer();
      await savePrayerSettings(
        await harnessRef(tester, container),
        lat: 30.0444,
        long: 31.2357,
        method: PrayerMethods.egyptian,
        asrCalc: PrayerMadhabs.shafi,
        city: _cairo,
      );
      expect(todayPrayerSchedule(), isNotNull);
      expect(islamicWeekdayNow(), inInclusiveRange(1, 7));
      container.dispose();
    });
  });
}
