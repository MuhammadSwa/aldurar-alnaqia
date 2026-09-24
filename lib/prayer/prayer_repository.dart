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
/// pure derivations of (schedule, now) computed on every use
/// (see `nextAt`, `weekdayAt`). That is what makes manual system-clock
/// changes self-healing with no refresh protocol: there is nothing cached
/// that a clock jump could invalidate.
class PrayerRepository {
  /// Shared instance used by the providers and the standalone helpers, so
  /// every caller shares one date-keyed cache. Tests should construct a
  /// fresh `PrayerRepository()` instead.
  static final PrayerRepository instance = PrayerRepository();

  /// At most today + yesterday are ever read (`prevAt` touches both around
  /// Fajr); one spare slot absorbs a midnight race without thrashing.
  static const int _maxCachedDays = 3;

  final Map<String, PrayerSchedule> _days = {};

  /// Schedule for [now]'s civil day in `settings.timezone`, or null when
  /// unconfigured/invalid. Cheap after the first call per day: one solar
  /// calculation per (settings, civil day), then a map hit.
  PrayerSchedule? scheduleFor(PrayerSettings settings, DateTime now) {
    final location = settings.locationOrNull;
    if (location == null) return null;
    final zoned = tz.TZDateTime.from(now, location);
    final key =
        '${settings.fingerprint}|${zoned.year}-${zoned.month}-${zoned.day}';
    final hit = _days[key];
    if (hit != null) return hit;
    // A settings change keys differently; drop entries no other day can use.
    _days.removeWhere((k, _) => !k.startsWith(settings.fingerprint));
    while (_days.length >= _maxCachedDays) {
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
    final resolved = _resolve(settings, now);
    if (resolved == null) return null;
    return resolved.schedule.nextEventAt(resolved.zoned);
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
    final resolved = _resolve(settings, now);
    if (resolved == null) return null;
    final hit = _latestAtOrBefore(
      resolved.schedule.ordered,
      resolved.zoned,
    );
    if (hit != null) return hit;
    // Before today's Fajr: look one civil day back. Duration arithmetic
    // (not day - 1 field math) so month/year boundaries and DST are correct.
    final yesterday = scheduleFor(
      settings,
      resolved.zoned.subtract(const Duration(days: 1)),
    );
    if (yesterday == null) return null;
    return _latestAtOrBefore(yesterday.ordered, resolved.zoned);
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
    final nowMs =
        tz.TZDateTime.from(now, prev.time.location).millisecondsSinceEpoch;
    if (nowMs < prevMs) return null;
    return ((nowMs - prevMs) / (nextMs - prevMs)).clamp(0.0, 1.0);
  }

  /// Islamic weekday for [now] (Monday=1, Sunday=7; the day flips at
  /// Maghrib). Always derived live — never cached.
  int weekdayAt(PrayerSettings settings, DateTime now) {
    final resolved = _resolve(settings, now);
    if (resolved == null) return now.weekday;
    return islamic_date.islamicWeekday(
      now: resolved.zoned,
      maghrib: resolved.schedule.maghrib,
    );
  }

  /// Next instant the UI must rebuild at: the earlier of the next event and
  /// next midnight, plus a 1-second grace — or null when unconfigured or
  /// already past (callers re-arm instead of scheduling the past). Pure and
  /// deterministic: the single source for the nudge timer, unit-tested.
  tz.TZDateTime? nextBoundaryAt(PrayerSettings settings, DateTime now) {
    final resolved = _resolve(settings, now);
    if (resolved == null) return null;
    final atNext = resolved.schedule.nextEventAt(resolved.zoned).time;
    // Duration arithmetic (not day + 1 field math) so month/year boundaries
    // and DST are correct — same rule as the backward lookup in [prevAt].
    // `civilDate` is this day's midnight in-zone, so +1 day is next midnight.
    final midnight = resolved.schedule.civilDate.add(
      const Duration(days: 1),
    );
    final target =
        (atNext.isBefore(midnight) ? atNext : midnight).add(
      const Duration(seconds: 1),
    );
    return target.isAfter(resolved.zoned) ? target : null;
  }

  /// Shared `scheduleFor` + in-zone conversion. Every derivation starts here
  /// so the validate/resolve/convert prologue lives in one place.
  ({PrayerSchedule schedule, tz.TZDateTime zoned})? _resolve(
    PrayerSettings settings,
    DateTime now,
  ) {
    final location = settings.locationOrNull;
    if (location == null) return null;
    final zoned = tz.TZDateTime.from(now, location);
    final schedule = scheduleFor(settings, zoned);
    if (schedule == null) return null;
    return (schedule: schedule, zoned: zoned);
  }

  PrayerEvent? _latestAtOrBefore(
    List<PrayerEvent> ordered,
    tz.TZDateTime zoned,
  ) {
    for (var i = ordered.length - 1; i >= 0; i--) {
      final event = ordered[i];
      if (!event.time.isAfter(zoned)) return event;
    }
    return null;
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
  try {
    final settings = SharedPreferencesService.loadPrayerSettings();
    final location = settings.locationOrNull;
    if (location == null) return null;
    return PrayerRepository.instance.scheduleFor(
      settings,
      tz.TZDateTime.now(location),
    );
  } catch (_) {
    return null;
  }
}

/// Current Islamic weekday for non-Riverpod callers. Never throws.
///
/// Loads settings once and reuses one `now`, instead of going through
/// [todayPrayerSchedule] (which would resolve the schedule twice).
int islamicWeekdayNow() {
  try {
    final settings = SharedPreferencesService.loadPrayerSettings();
    final location = settings.locationOrNull;
    if (location == null) return DateTime.now().weekday;
    final now = tz.TZDateTime.now(location);
    return PrayerRepository.instance.weekdayAt(settings, now);
  } catch (_) {
    return DateTime.now().weekday;
  }
}
