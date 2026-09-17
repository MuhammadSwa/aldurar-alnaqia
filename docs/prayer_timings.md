# Prayer timings: architecture, contract & battery notes

## Ownership

- **Flutter** owns all prayer math (`adhan_dart` via `PrayerScheduleCalculator`)
  and precomputes a 30-day epoch-ms timetable plus Hijri labels on every
  settings save / startup.
- **Kotlin** (`PrayerNotificationService`) is a dumb renderer + alarm
  scheduler: it reads the precomputed `days`/`midnights` tables and performs
  no solar or Hijri calculation, so it keeps working after the Dart VM is
  killed. Single source of truth — no method/madhab/Hijri divergence possible.

## Cross-platform contract (v3)

Defined in Dart (`lib/prayer/prayer_schedule.dart`, `buildNativeConfigMap`)
and read in `PrayerNotificationService.kt`:

- settings echo (informational; Kotlin does not calculate from them):
  `method`, `asrCalculation`, `highLatitudeRule` (+ `lat`/`lng` for the
  no-location sentinel, `timezone` for display formatting)
- `days`: 30 maps of `{fajr, sunrise, dhuhr, asr, maghrib, isha}` epoch-ms
  plus Hijri labels `hb` (before Maghrib) and `ha` (from Maghrib on), one
  per civil day in `timezone` starting today
- `midnights`: 31 civil-midnight epoch-ms boundaries in `timezone`
- event IDs are typed enums on both sides (`PrayerEventId` / `EventId`);
  Arabic labels exist **only** at render time, never as identifiers
- timestamps cross the boundary as epoch milliseconds
- native config JSON carries a `version` field for future migrations.
  Payloads without tables or Hijri labels read as expired and show
  "open the app to refresh" until one app open rewrites them.

## Flutter timing model: derive, don't store

The core rule: **no stored "now"-dependent state**. The only cache is
`PrayerRepository`'s civil-date-keyed schedule map (key embeds the settings
fingerprint, so staleness is impossible by construction). Next prayer,
weekday, and Hijri labels are pure derivations of (schedule, now) computed
on every use — manual system-clock changes self-heal with no refresh
protocol, because there is nothing cached that a clock jump could
invalidate. (The old stored-`nextPrayerInfo` design went stale on backward
clock jumps and needed restart; that entire bug class is gone.)

- `lib/prayer/` holds the framework-free domain: schedule model +
  calculator, repository, Hijri labels, native payload, and thin Riverpod
  glue (`prayer_providers.dart`: settings/label state, derived
  `prayerViewProvider`, one-shot nudge timer). No `tz.local` mutation
  anywhere — every `now` carries its explicit zone.
- There is **no global 1-second ticker**. `NextPrayerCountdown` owns a local
  1s timer while mounted; navigating away disposes it, so reading elsewhere
  costs zero Dart wakeups. Each tick derives the next prayer live and pokes
  `prayerNudgeProvider` on change, so highlight/weekday/dates rebuild too.
- One app-wide one-shot boundary timer (~7 wakeups/day) nudges derived
  providers at the next event/midnight for screens without a ticker (e.g.
  the home weekday). A misfire is cosmetic-only by design.
- Unconfigured (no saved location) is just a null view → setup prompt.
  There is no init/loading state: prefs and the tz database are ready
  before `runApp`.
- Settings writes are atomic: `savePrayerSettings` → one prefs write + one
  native-table push + provider publish. No field-level setters.
- Non-provider callers (routing weekday, Yousria cycle) share the
  standalone `todayPrayerSchedule()` / `islamicWeekdayNow()` helpers backed
  by the same repository instance.

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

## Tests

- `test/prayer_schedule_test.dart`: golden epoch-ms fixtures (Cairo,
  Makkah, Karachi, London high-lat, NYC DST transition, both madhabs,
  boundaries, after-Isha→Fajr, Maghrib flip) with ±60s tolerance, plus
  `buildNativeConfigMap` range tests (30 days, 31 midnights, Hijri labels,
  day-1 matches goldens).
- `test/prayer_providers_test.dart`: save flows, and the key regression —
  a backward clock jump flips Asr→Fajr through pure derivation with zero
  refresh calls. ProviderContainer tests dispose the container explicitly:
  the boundary timer is app-lifecycle state and `testWidgets` fails on any
  timer pending at test end.
- `test/prayer_widgets_test.dart`: card/countdown render from the real
  providers (no notifier stubs), Hijri label helper, notification dialog.

## Profiling

- Flutter: DevTools → rebuild counts on the timings screen; confirm only
  the countdown text rebuilds per second, and no timers fire off-screen
  (timeline should show ~7 `Timer` events/day from the nudge notifier).
- Android: `adb shell dumpsys batterystats` / Battery Historian; confirm
  exact alarms only at prayer boundaries (`adb shell dumpsys alarm` shows
  one pending `PRAYER_ALARM_TRIGGER` at a time).
