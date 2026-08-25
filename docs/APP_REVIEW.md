# App Review — الدرر النقية

_Date: 2026-08-25 · flutter analyze: clean · version 1.0.0+1_

## Current State

Solid foundation after the GetX→Riverpod migration: analyzer passes clean,
state is immutable (`AudioState`, `PrayerState`), audio subsystem has proper
error recovery (exponential backoff, local→remote fallback), and routing uses
typed targets.

---

## 🔴 High Priority

### 1. Testing is effectively absent
`test/widget_test.dart` renders a fake app — none of the actual code is tested.
Highest-value tests:
- `PrayerTimeings.getPrayersTimings()` — method switching, high-latitude rules, `fajrAfter` handling
- `islamicWeekdayNow()` / Maghrib day-change logic (a bug here mislabels the daily wird)
- `BookmarksNotifier` toggle/add/remove round-trip
- `DownloaderService` status cache behavior
- Audio recovery retry scheduling

### 2. No CI pipeline
Add `.github/workflows/ci.yml`: `flutter analyze && flutter test` on every PR.

### 3. File-status cache collision bug ⛔ FIXED — see below
`DownloaderService._fileStatusCache` was keyed by **id only**, but files live
under two directories (`narrations/`, `books/`). A book and a narration sharing
an id corrupted each other's cached status.
**Fix:** cache keys are now `'${type.name}/$id'`; `cachedStatus`,
`cancelDownload`, `_statusFutures`, and the task-update handler all carry the
type (derived from `task.directory`). Note: progress notifiers are still keyed
by raw task id — a book/narration id collision would also conflict at the
downloader level, so ids should be namespaced at the data level eventually.

### 4. Cold-start performance ⛔ FIXED — see below
`main()` awaited notification-channel creation, permission request, and
foreground-service start before the first frame → white screen on Android.
**Fix:** `NotificationHelper.initialize()` and
`initializePrayerForegroundService()` now run in a post-first-frame callback.

### 5. Silent SharedPreferences failures
- `_sharedPreferences?.setDouble(...)` silently no-ops if init failed — no diagnostics.
- Location uses `0.0/0.0` as "not set" sentinel; store an explicit `hasLocation` flag instead.
- `getYousriaBeginning()` performs a *write* inside a getter (side effect).
- Consider injecting prefs through Riverpod rather than statics (as done for `StorageService`).

---

## 🟡 Medium Priority

### 6. Side effects in build
`home_screen.dart` calls `registerScaffoldKey(_scaffoldKey)` inside `build()`.
Move to `initState()` + unregister in `dispose()` — keys accumulate across rebuilds.

### 7. Router issues
- `debugLogDiagnostics: true` left on for release builds (`app_router.dart`).
- `appRouterProvider` is a family keyed by `initialLocation`; a plain provider suffices since the hint never changes at runtime.

### 8. Countdown rebuild scope
The 1-second tick updates `timeLeft` in `PrayerState`. Verify every countdown
widget uses `ref.watch(prayerProvider.select((s) => s.timeLeft))`. Also pause
the timer when backgrounded (`AppLifecycleListener`) to save battery.

### 9. Dependency hygiene
- `media_kit_libs_audio: any` / `media_kit_libs_linux: any` — pin versions.
- `permission_handler_android` pinned to 13 pending AGP upgrade — schedule it.
- Remove commented-out deps, leftover empty `index.lock`, move root-level logo images into `assets/`.

---

## 🟢 Lower Priority

### 10. Observability
Local logger exists but no crash reporting. Add Sentry or Crashlytics.

### 11. String management
Arabic strings hardcoded everywhere. Extracting to ARB files gives consistency
and easier proofreading of religious text. Replace hand-rolled `_formatTime`
with `intl.DateFormat`.

### 12. Weak typing
`validatePrayerTimes()` returns `Map<String, dynamic>` — convert to a data
class. Same for `(DateTime?, String)` record in `PrayerState.nextPrayerInfo`.

### 13. UX polish
- Empty bookmark state is a bare TODO — add friendly prompt + CTA.
- Consistent loading/error/empty states across screens.
- `Semantics` labels on zikr text and audio controls for TalkBack users.

---

## Suggested Order of Attack

1. ~~CI workflow + real unit tests~~ (next)
2. ~~Fix download cache key collision~~ ✅
3. Harden SharedPreferences
4. ~~Defer bootstrap work past first frame~~ ✅
5. Dependency cleanup + release readiness
