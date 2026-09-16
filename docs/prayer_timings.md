# Prayer timings: architecture, contract & battery notes

## Ownership

- **Flutter** owns interactive display state while the app is open.
- **Kotlin** (`PrayerNotificationService`) owns background notification/alarm
  execution. It must work after the Dart VM is killed — so both sides keep
  their own calculator.

## Cross-platform contract (v1)

Defined once in Dart (`lib/screens/prayer_timings_screen/models/prayer_schedule.dart`)
and mirrored in `PrayerNotificationService.kt`:

- stable method IDs: `egyptian`, `karachi`, `muslim_world_league`, `dubai`,
  `qatar`, `kuwait`, `turkey`, `tehran`, `singapore`, `umm_al_qura`,
  `north_america`, `moon_sighting_committee`
- madhab IDs: `shafi` | `hanafi`
- high-latitude IDs: `middle_of_night` | `seventh_of_night` | `twilight_angle`
- timezone: required IANA ID; empty/invalid is rejected visibly, never guessed
- event IDs are typed enums on both sides (`PrayerEventId` / `EventId`);
  Arabic labels exist **only** at render time, never as identifiers
- timestamps cross the boundary as epoch milliseconds
- native config JSON carries a `version` field for future migrations

Known divergence: adhan2 0.0.5 (Kotlin) has no TEHRAN method and no
`maghribAngle`, so Kotlin approximates Tehran as
`OTHER(fajr 17.7, isha 14.0)` while Dart uses full Tehran parameters
(fajr 17.7, isha 14, maghribAngle 4.5). Expect Maghrib to differ by a few
minutes for `tehran` until adhan2 is upgraded.

## Flutter timing model

- `PrayerTimingsNotifier` is the **single owner** of prayer timing. It
  recalculates only on init, settings change, event boundary, or midnight,
  then arms **one** one-shot boundary timer (~7 wakeups/day).
- There is **no global 1-second ticker**. `NextPrayerCountdown` owns a local
  1s timer while mounted; navigating away disposes it, so reading elsewhere
  costs zero Dart wakeups.
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
boundaries, after-Isha→Fajr, Maghrib flip) with ±60s tolerance. The same
fixture set should be mirrored in Kotlin tests; any larger mismatch fails.

## Profiling (before/after)

- Flutter: DevTools → rebuild counts on the timings screen; confirm only
  the countdown text rebuilds per second, and no timers fire off-screen
  (timeline should show ~7 `Timer` events/day from the notifier).
- Android: `adb shell dumpsys batterystats` / Battery Historian; confirm
  exact alarms only at prayer boundaries (`adb shell dumpsys alarm` shows
  one pending `PRAYER_ALARM_TRIGGER` at a time).
