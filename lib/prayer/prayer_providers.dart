import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:aldurar_alnaqia/prayer/prayer_repository.dart';
import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/city_directory.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/location_timezone.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';

/// Thin Riverpod glue over [PrayerRepository]. Holds no prayer data itself:
/// one stored config plus derived values. See `prayer_repository.dart` for
/// why nothing cached can go stale.
///
/// Battery profile: one 1-second timer while the countdown is mounted, one
/// one-shot boundary timer app-wide (~7 wakeups/day), zero Dart wakeups
/// otherwise.

/// Stored prayer configuration: calculation inputs plus the display label
/// saved alongside them ('القاهرة، مصر'). Single writer:
/// [savePrayerSettings] publishes through [PrayerConfigNotifier.publish].
class PrayerConfig {
  final PrayerSettings settings;
  final String cityLabel;

  const PrayerConfig({required this.settings, required this.cityLabel});
}

class PrayerConfigNotifier extends Notifier<PrayerConfig> {
  @override
  PrayerConfig build() => PrayerConfig(
        settings: SharedPreferencesService.loadPrayerSettings(),
        cityLabel: SharedPreferencesService.getPrayerCityLabel(),
      );

  void publish(PrayerSettings settings, String cityLabel) =>
      state = PrayerConfig(settings: settings, cityLabel: cityLabel);
}

final prayerConfigProvider =
    NotifierProvider<PrayerConfigNotifier, PrayerConfig>(
  PrayerConfigNotifier.new,
);

/// Rebuild nudge. Bumped at event boundaries (one-shot timer) and whenever
/// the ticking countdown observes a new next prayer (covers manual clock
/// jumps within a second). Cosmetic consumers (highlight, weekday, dates)
/// rebuild on this; correctness never depends on it — the countdown always
/// derives live values from wall-clock time.
final prayerNudgeProvider =
    NotifierProvider<PrayerNudgeNotifier, int>(PrayerNudgeNotifier.new);

/// Everything the prayer UI needs, derived fresh on each nudge or config
/// change. Null when unconfigured (setup prompt takes over — there is no
/// separate loading state; prefs and the tz database are ready before
/// `runApp`, so a null view unambiguously means "no saved location").
class PrayerView {
  final PrayerSettings settings;
  final PrayerSchedule schedule;
  final PrayerEvent next;
  final int weekday;
  final tz.TZDateTime today;
  final String cityLabel;

  const PrayerView({
    required this.settings,
    required this.schedule,
    required this.next,
    required this.weekday,
    required this.today,
    required this.cityLabel,
  });
}

final prayerViewProvider = Provider<PrayerView?>((ref) {
  ref.watch(prayerNudgeProvider);
  final config = ref.watch(prayerConfigProvider);
  final settings = config.settings;
  if (settings.validate() != null) return null;
  final repo = PrayerRepository.instance;
  final location = _zoneOf(settings);
  if (location == null) return null;
  final now = tz.TZDateTime.now(location);
  final schedule = repo.scheduleFor(settings, now);
  if (schedule == null) return null;
  return PrayerView(
    settings: settings,
    schedule: schedule,
    next: schedule.nextEventAt(now),
    weekday: repo.weekdayAt(settings, now),
    today: now,
    cityLabel: config.cityLabel,
  );
});

tz.Location? _zoneOf(PrayerSettings settings) {
  try {
    return tz.getLocation(settings.timezone);
  } catch (_) {
    return null;
  }
}

/// Owns the single one-shot boundary timer. On fire it bumps the version so
/// derived providers re-evaluate; [poke] does the same when the countdown
/// observes a next-prayer change, and also re-arms (a clock jump invalidates
/// the previously armed instant). Re-arms on every config change. Never
/// stores prayer data, so a misfire is at worst a cosmetic delay.
///
/// Note the dependency direction: the view watches this nudge, while this
/// notifier watches only the config. The reverse — listening to the view
/// here — would be a dependency cycle.
class PrayerNudgeNotifier extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(prayerConfigProvider, (_, __) => _rearm());
    _rearm();
    return 0;
  }

  void poke() {
    state++;
    _rearm();
  }

  void _rearm() {
    _timer?.cancel();
    final settings = ref.read(prayerConfigProvider).settings;
    final now = DateTime.now();
    final target = PrayerRepository.instance.nextBoundaryAt(settings, now);
    if (target == null) return;
    final delay = target.difference(tz.TZDateTime.from(now, target.location));
    if (delay.isNegative) return;
    _timer = Timer(delay, () {
      if (!ref.mounted) return;
      state++;
      _rearm();
    });
  }
}

/// Validates, persists, and publishes interdependent prayer settings as one
/// atomic unit: one prefs write + one native-table push + one provider
/// publish, so no reader can observe a half-saved location/timezone/method.
/// Returns false when the timezone can't be resolved (nothing saved).
///
/// Display label only: GPS (city == null) → nearest city within 50 km, else
/// coordinates. Prayer math keeps using the exact coordinates.
Future<bool> savePrayerSettings(
  WidgetRef ref, {
  required double lat,
  required double long,
  required String method,
  required String asrCalc,
  String? highLatitudeRule,
  City? city,
}) async {
  final directory = await ref.read(cityDirectoryProvider.future);

  final labelCity = city ??
      LocationTimezone.nearestCity(
        latitude: lat,
        longitude: long,
        cities: directory.cities,
      );
  final cityLabel = labelCity != null
      ? directory.cityLabel(labelCity)
      : '${lat.toStringAsFixed(2)}°، ${long.toStringAsFixed(2)}°';

  final timezone = LocationTimezone.resolve(
    latitude: lat,
    longitude: long,
    cities: directory.cities,
    selectedCity: city,
  );
  if (timezone == null) return false;

  await SharedPreferencesService.savePrayerSettings(
    latitude: lat,
    longitude: long,
    method: method,
    asrCalculation: asrCalc,
    timezone: timezone,
    highLatitudeRule: highLatitudeRule,
    city: city,
    cityLabel: cityLabel,
  );
  // The element may be gone if the settings screen closed mid-save; in that
  // case there is nobody left to notify, but the stored settings are still
  // the source of truth, so report success regardless.
  if (!ref.context.mounted) return true;
  ref.read(prayerConfigProvider.notifier).publish(
        SharedPreferencesService.loadPrayerSettings(),
        cityLabel,
      );
  return true;
}
