import 'package:aldurar_alnaqia/common/helpers/islamic_date.dart'
    as islamic_date;
import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

/// The single owner of prayer timetable data.
///
/// Design: the ONLY cache here is a civil-date-keyed map of daily schedules.
/// The key embeds the settings fingerprint, so a settings change can never
/// read another configuration's entries, and each entry is only ever served
/// for its own civil day — staleness is impossible by construction.
///
/// Deliberately stores NO "next prayer", NO weekday, NO flags: those are
/// pure derivations of (schedule, now) computed by callers on every use
/// (see `nextAt`, `islamicWeekday`). That is what makes manual system-clock
/// changes self-healing with no refresh protocol: there is nothing cached
/// that a clock jump could invalidate.
class PrayerRepository {
  /// Shared instance used by the providers and the standalone helpers, so
  /// every caller shares one date-keyed cache. Tests should construct a
  /// fresh `PrayerRepository()` instead.
  static final PrayerRepository instance = PrayerRepository();

  final Map<String, PrayerSchedule> _days = {};

  /// Schedule for [now]'s civil day in `settings.timezone`, or null when
  /// unconfigured/invalid. Cheap after the first call per day: one solar
  /// calculation per (settings, civil day), then a map hit.
  PrayerSchedule? scheduleFor(PrayerSettings settings, DateTime now) {
    final location = _locationOf(settings);
    if (location == null) return null;
    final zoned = tz.TZDateTime.from(now, location);
    final key =
        '${settings.fingerprint}|${zoned.year}-${zoned.month}-${zoned.day}';
    final hit = _days[key];
    if (hit != null) return hit;
    // A settings change keys differently; drop entries no other day can use.
    _days.removeWhere((k, _) => !k.startsWith(settings.fingerprint));
    if (_days.length > 4) {
      _days.remove(_days.keys.first);
    }
    final schedule = PrayerScheduleCalculator.calculate(
      settings: settings,
      date: zoned,
    );
    if (schedule != null) _days[key] = schedule;
    return schedule;
  }

  /// Next event strictly after [now] (tomorrow's Fajr after Isha), or null
  /// when unconfigured. Always derived live — never cached.
  PrayerEvent? nextAt(PrayerSettings settings, DateTime now) {
    final schedule = scheduleFor(settings, now);
    if (schedule == null) return null;
    final location = schedule.civilDate.location;
    return schedule.nextEventAt(tz.TZDateTime.from(now, location));
  }

  /// Previous event at or before [now] on the continuous timeline, or null
  /// when unconfigured.
  ///
  /// Prayer time is continuous; civil-day schedules are just cache buckets.
  /// Before today's Fajr there is no event in today's bucket, so the answer
  /// lives in yesterday's bucket (yesterday's Isha in practice — resolved
  /// generically as the latest event at or before [now], never assumed).
  /// Symmetric to [nextAt], which already crosses midnight forward via
  /// tomorrow's Fajr; this crosses midnight backward the same way.
  PrayerEvent? prevAt(PrayerSettings settings, DateTime now) {
    final schedule = scheduleFor(settings, now);
    if (schedule == null) return null;
    final location = schedule.civilDate.location;
    final zoned = tz.TZDateTime.from(now, location);
    for (var i = schedule.ordered.length - 1; i >= 0; i--) {
      final event = schedule.ordered[i];
      if (!event.time.isAfter(zoned)) return event;
    }
    // Before today's Fajr: look one civil day back. Duration arithmetic
    // (not day - 1 field math) so month/year boundaries and DST are correct.
    final yesterday =
        scheduleFor(settings, zoned.subtract(const Duration(days: 1)));
    if (yesterday == null) return null;
    for (var i = yesterday.ordered.length - 1; i >= 0; i--) {
      final event = yesterday.ordered[i];
      if (!event.time.isAfter(zoned)) return event;
    }
    return null;
  }

  /// Elapsed fraction from the previous event to the next one (0–1), or null
  /// when either end can't be determined. Single timeline query for the
  /// countdown bar — callers never think in civil days. Ticks with wall-clock
  /// time; pure derivation of ([prevAt], [nextAt]), so clock jumps
  /// self-correct on the next call.
  double? progressAt(PrayerSettings settings, DateTime now) {
    final prev = prevAt(settings, now);
    final next = nextAt(settings, now);
    if (prev == null || next == null) return null;
    final prevMs = prev.time.millisecondsSinceEpoch;
    final nextMs = next.time.millisecondsSinceEpoch;
    if (nextMs <= prevMs) return null;
    final location = prev.time.location;
    final nowMs =
        tz.TZDateTime.from(now, location).millisecondsSinceEpoch;
    if (nowMs < prevMs) return null;
    return ((nowMs - prevMs) / (nextMs - prevMs)).clamp(0.0, 1.0);
  }

  /// Islamic weekday for [now] (Monday=1, Sunday=7; the day flips at
  /// Maghrib). Always derived live — never cached.
  int weekdayAt(PrayerSettings settings, DateTime now) {
    final schedule = scheduleFor(settings, now);
    if (schedule == null) return now.weekday;
    final location = schedule.civilDate.location;
    final zoned = tz.TZDateTime.from(now, location);
    return islamic_date.islamicWeekday(now: zoned, maghrib: schedule.maghrib);
  }

  /// Next instant the UI must rebuild at: the earlier of the next event and
  /// next midnight, plus a 1-second grace — or null when unconfigured or
  /// already past (callers re-arm instead of scheduling the past). Pure and
  /// deterministic: the single source for the nudge timer, unit-tested.
  tz.TZDateTime? nextBoundaryAt(PrayerSettings settings, DateTime now) {
    final schedule = scheduleFor(settings, now);
    if (schedule == null) return null;
    final location = schedule.civilDate.location;
    final zoned = tz.TZDateTime.from(now, location);
    final atNext = schedule.nextEventAt(zoned).time;
    final midnight = tz.TZDateTime(
      location,
      zoned.year,
      zoned.month,
      zoned.day + 1,
    );
    final target =
        (atNext.isBefore(midnight) ? atNext : midnight).add(
      const Duration(seconds: 1),
    );
    return target.isAfter(zoned) ? target : null;
  }

  tz.Location? _locationOf(PrayerSettings settings) {
    if (settings.validate() != null) return null;
    try {
      return tz.getLocation(settings.timezone);
    } catch (_) {
      return null;
    }
  }

  /// Cache size probe for tests.
  @visibleForTesting
  int get cacheSize => _days.length;
}

/// Today's schedule from stored settings, or null when unconfigured.
/// Shared entry point for non-Riverpod callers (routing, Yousria).
/// Never throws; recomputes per civil day at most (no stale state — the
/// cache key includes the date and settings fingerprint).
PrayerSchedule? todayPrayerSchedule() {
  final settings = SharedPreferencesService.loadPrayerSettings();
  if (settings.validate() != null) return null;
  tz.Location location;
  try {
    location = tz.getLocation(settings.timezone);
  } catch (_) {
    return null;
  }
  return PrayerRepository.instance.scheduleFor(
    settings,
    tz.TZDateTime.now(location),
  );
}

/// Current Islamic weekday for non-Riverpod callers. Never throws.
int islamicWeekdayNow() {
  final schedule = todayPrayerSchedule();
  if (schedule == null) return DateTime.now().weekday;
  final location = schedule.civilDate.location;
  return PrayerRepository.instance.weekdayAt(
    schedule.settings,
    tz.TZDateTime.now(location),
  );
}
