# Prayer timings: architecture, contract & battery notes

## Ownership

- **Flutter** owns all prayer math (`adhan_dart` via `PrayerScheduleCalculator`)
  and precomputes a 30-day epoch-ms timetable on every settings save / startup.
- **Kotlin** (`PrayerNotificationService`) is a dumb renderer + alarm scheduler:
  it reads the precomputed `days`/`midnights` tables and performs no solar
  calculation, so it keeps working after the Dart VM is killed. Single source
  of truth — no method/madhab divergence possible.

## Cross-platform contract (v2)

Defined in Dart (`lib/screens/prayer_timings_screen/models/prayer_schedule.dart`,
`buildNativeConfigMap`) and read in `PrayerNotificationService.kt`:

- settings echo (informational; Kotlin does not calculate from them):
  `method`, `asrCalculation`, `highLatitudeRule` (+ `lat`/`lng` for the
  no-location sentinel, `timezone` for display formatting, `hijriOffset`)
- `days`: 30 maps of `{fajr, sunrise, dhuhr, asr, maghrib, isha}` epoch-ms,
  one per civil day in `timezone` starting today
- `midnights`: 31 civil-midnight epoch-ms boundaries in `timezone`
- event IDs are typed enums on both sides (`PrayerEventId` / `EventId`);
  Arabic labels exist **only** at render time, never as identifiers
- timestamps cross the boundary as epoch milliseconds
- native config JSON carries a `version` field for future migrations
  (v1 = old dual-calculator config with no tables; Kotlin treats it as
  expired and shows "open the app to refresh" until one app open rewrites v2)

## Flutter timing model

- `PrayerTimingsNotifier` is the **single owner** of prayer timing. It
  recalculates on init, settings change, event boundary, midnight,
  app-resume, or a detected system-clock jump, then arms **one** one-shot
  boundary timer (~7 wakeups/day).
- There is **no global 1-second ticker**. `NextPrayerCountdown` owns a local
  1s timer while mounted; navigating away disposes it, so reading elsewhere
  costs zero Dart wakeups. Each tick calls the cheap `refresh()` guard
  (re-evaluates the next event from the cached schedule, no solar math),
  so a manual clock change re-syncs within a second instead of going stale
  until restart — a backward jump leaves the old target in the future, which
  a naive past-check would miss (`nextPrayerIsStale`).
- Timetable/weekday/Hijri widgets are pure `select()` renderers — they never
  recalculate and never rebuild per second.
- Settings writes are atomic: `savePrayerSettings` → one native refresh.
  Field-level setters are deprecated (half-written config risk).
- Non-provider callers (routing weekday, Yousria cycle) share one
  `todayPrayerSchedule()` entry point — a single solar calculation per call
  site instead of scattered `PrayerTimes` constructions.

## Native policy (Android)

- Display countdown is a system `Chronometer`: SystemUI ticks it with zero
  app wakeups.
- **Exact alarms** (`setExactAndAllowWhileIdle`) fire for alertable
  prayers (never sunrise/midnight). Everything else uses inexact
  `setAndAllowWhileIdle`.
- Concurrent refreshes (save + alarm + boot) are serialized with a `Mutex`
  and coalesced — no overlapping notify/alarm cycles.
- `BootReceiver` logs start failures instead of swallowing them. Note:
  user force-stop clears alarms until the app is reopened (platform behavior).

## Parity tests

`test/prayer_schedule_test.dart` holds golden epoch-ms fixtures (Cairo,
Makkah, Karachi, London high-lat, NYC DST transition, both madhabs,
boundaries, after-Isha→Fajr, Maghrib flip) with ±60s tolerance, plus
`buildNativeConfigMap` range tests (30 days, 31 midnights, strictly
increasing, day-1 matches goldens). Kotlin has no calculator left to
mirror — its table-selection (`findPlan`) is covered by review, not fixtures.

## Profiling (before/after)

- Flutter: DevTools → rebuild counts on the timings screen; confirm only
  the countdown text rebuilds per second, and no timers fire off-screen
  (timeline should show ~7 `Timer` events/day from the notifier).
- Android: `adb shell dumpsys batterystats` / Battery Historian; confirm
  exact alarms only at prayer boundaries (`adb shell dumpsys alarm` shows
  one pending `PRAYER_ALARM_TRIGGER` at a time).
