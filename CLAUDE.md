# CLAUDE.md

Project context for `aldurar_alnaqia` — a Flutter app of Shadhili awrād (Arabic, RTL).

## iOS builds fail on this machine without a workaround

**Read this before touching the iOS target.** It is a machine-configuration
problem, not a project bug, and the error message points nowhere near the cause.

### Symptom

Any iOS build (simulator *or* release device) dies in the Dart native-assets
hook:

```
Bad state: No element
#0  Iterable.first (dart:core/iterable.dart:663:7)
#1  firstLineOfStdout (.../objective_c-9.x.x/hook/build.dart:198:8)
#2  sdkPath (.../objective_c-9.x.x/hook/build.dart:189:10)
...
Target build_hooks failed: Error: Building native assets failed.
```

`objective_c` arrives transitively via `path_provider_foundation`.

### Root cause

This Mac's system `xcode-select` points at CommandLineTools, which ships macOS
SDKs only — no iOS SDKs:

```
/var/db/xcode_select_link -> /Library/Developer/CommandLineTools
```

`~/.zshrc` exports `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`,
which masks this in a normal terminal — `xcode-select -p` looks correct. But the
Dart hooks runner passes hooks a **filtered environment**. Its allowlist
(`hooks_runner/lib/src/build_runner/build_runner.dart`, `includeHookEnvironmentVariable`)
forwards `PATH` and `HOME` but **not `DEVELOPER_DIR`**. So inside the hook,
`/usr/bin/xcrun` falls back to the `xcode_select_link` and fails:

```
xcrun: error: SDK "iphonesimulator" cannot be located
```

The hook's `assert(result.exitCode == 0)` is compiled out in AOT, so instead of
reporting that, it calls `.first` on empty stdout and throws `Bad state`.

### Current workaround (no sudo needed)

`PATH` *is* forwarded, so a shim re-injects `DEVELOPER_DIR`:

- `~/bin/xcrun` — sets `DEVELOPER_DIR` if unset, then `exec`s `/usr/bin/xcrun`
- `~/.zshrc` prepends `~/bin` to `PATH` (must come before `/usr/bin`)

Verified by clearing `.dart_tool/hooks_runner` and building both ways:
without `~/bin` on `PATH` the build fails; with it, both the simulator and the
release device build succeed.

**Limitation:** `.zshrc` is sourced by *interactive* shells only. Terminal builds
get the shim; **Xcode GUI Archive and CI do not.** Until that is addressed,
archive from the terminal with `flutter build ipa` and upload the `.ipa` via
Transporter, rather than Xcode's Archive menu.

Moving the `PATH` line to `~/.zshenv` would cover non-interactive shells too.

### Permanent fix

Have an admin run this, then delete `~/bin/xcrun` and the `~/.zshrc` PATH line:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

The current user is not in the sudoers file, so this needs whoever administers
the machine.

### Debugging note

`zsh -l -c '...'` does **not** source `.zshrc`, so it is useless for testing this
shim. Also, hook results are cached in `.dart_tool/hooks_runner` — clear it
before any test, or a stale success will look like a fix.

## iOS release facts

- **Bundle ID:** `com.aldurar.alnaqia` (matches Android `applicationId`).
  Was `com.example.dorar`; Apple rejects `com.example.*`.
- **Deployment target:** iOS 15.0. Flutter 3.47 dropped iOS 12, and
  `permission_handler` / `geolocator` / `just_audio` need higher.
- **No Podfile — this project uses Swift Package Manager.** Flutter 3.47 uses SPM
  for iOS by default. Do not add CocoaPods.
- **iOS icon is `ios/Runner/AppIcon.icon` (Icon Composer), not the asset catalog.**
  It is a Liquid Glass icon, so Clear/Tinted home screens render it as glass.
  It shares the name `AppIcon` with `Assets.xcassets/AppIcon.appiconset`, and
  Xcode lets the `.icon` win: it also renders the flat fallback images for
  iOS 15–25 from it. So `flutter_launcher_icons` no longer changes the iOS
  icon; edit the `.icon` in Icon Composer instead. Its layers must stay on a
  transparent background.
- **App icon must stay opaque.** App Store upload fails with `ITMS-90717` if the
  1024×1024 icon has an alpha channel. Xcode's renditions from the `.icon` are
  opaque (check `Opaque` in `xcrun assetutil --info Assets.car`). Android
  still uses `flutter_launcher_icons` with the transparent
  `app_logo_cropped.png` for adaptive icons.
- **`TARGETED_DEVICE_FAMILY = "1,2"`** — ships on iPad, so App Store submission
  needs iPad screenshots and the iPad layout gets reviewed.
- **Background audio** (`UIBackgroundModes: audio`) needs justifying in App Review
  notes: recitations continue with the screen locked.
- **`NSLocationAlwaysAndWhenInUseUsageDescription` is required even though the
  app never asks for Always.** `geolocator_apple` compiles in
  `requestAlwaysAuthorization`, so uploads without the key get `ITMS-90683`.
  Its `BYPASS_PERMISSION_LOCATION_ALWAYS` macro can't be set under SPM (it's a
  Podfile/Pods-target setting). Adding the key doesn't change the prompt:
  `PermissionHandler.m` checks the WhenInUse key first.
- **Privacy:** location is used on-device for prayer times only and is never
  transmitted. No analytics, Firebase, or HTTP client in the dependency tree.
- **UIScene lifecycle is mandatory.** An app built with the iOS 27 SDK without
  it crashes at launch on iOS 27 (`EXC_BREAKPOINT` in
  `_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`); build
  1.0.1 (3) shipped to TestFlight that way. Migrated by hand because
  Flutter's auto-migrator skips a customized `AppDelegate.swift`:
  `Info.plist` has `UIApplicationSceneManifest` → `FlutterSceneDelegate`, and
  `AppDelegate` registers plugins and the `app/storage` channel in
  `didInitializeImplicitFlutterEngine`. `window` is nil in
  `didFinishLaunching` now, so don't reach for `window?.rootViewController`
  there. See https://flutter.dev/to/uiscene-migration.

## Content

Audio and PDFs stream from `archive.org`. App Review may ask about rights to
third-party religious content.
