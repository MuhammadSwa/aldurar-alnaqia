import 'dart:async';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:aldurar_alnaqia/common/theme/dark_theme.dart';
import 'package:aldurar_alnaqia/router/app_router.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:desktop_window/desktop_window.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/audio_engine.dart';
import 'package:aldurar_alnaqia/audio/audio_handler.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/services/prayer_notification_service.dart';
import 'package:aldurar_alnaqia/services/notification_helper.dart';
import 'package:aldurar_alnaqia/common/helpers/logger.dart';

Future setDesktopWindow() async {
  await DesktopWindow.setMinWindowSize(const Size(600, 600));
  await DesktopWindow.setWindowSize(const Size(1300, 900));
}

Future<ProviderContainer> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Media notification + background audio (mobile). Requires the
  // audio_service entries in AndroidManifest.xml and the iOS audio
  // background mode.
  NarrationAudioHandler? audioHandler;
  if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
    audioHandler = await AudioService.init(
      builder: () => NarrationAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'com.example.aldurar_alnaqia.channel.audio',
        androidNotificationChannelName: 'تشغيل الصوت',
        androidNotificationChannelDescription: 'التحكم بتشغيل التلاوات',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    await NarrationAudioHandler.configureAudioSession();
  }

  if (UniversalPlatform.isWindows ||
      UniversalPlatform.isLinux ||
      UniversalPlatform.isMacOS) {
    await setDesktopWindow();
  }

  await SharedPreferencesService().init();

  final container = ProviderContainer(overrides: [
    storageProvider.overrideWithValue(await StorageService().init()),
    if (audioHandler != null)
      audioEngineProvider.overrideWithValue(
        JustAudioEngine(notifications: audioHandler),
      ),
  ]);

  return container;
}

Future<void> main() async {
  final container = await _bootstrap();

  final savedThemeMode = await AdaptiveTheme.getThemeMode();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MyApp(theme: savedThemeMode),
    ),
  );

  // Defer non-critical platform work (notification channel, permission
  // prompt, foreground service) until after the first frame so the UI
  // paints immediately instead of showing a white splash on Android.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_startPlatformServices());
  });
}

/// Notification channel + permission (Android 13+) and the native
/// prayer-countdown foreground service bridge (Android only).
Future<void> _startPlatformServices() async {
  try {
    await NotificationHelper.initialize();
    await initializePrayerForegroundService();
  } catch (e, st) {
    logError('Deferred platform service startup failed', e, st);
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key, required this.theme});
  final AdaptiveThemeMode? theme;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription<String>? _routeSub;

  @override
  void initState() {
    super.initState();
    // The native prayer notification asks us to navigate when the user taps
    // it (cold start included — Android buffers the tap until we're ready).
    _routeSub = onNotificationRouteTap.listen((route) {
      ref.read(appRouterProvider).go(route);
    });
  }

  @override
  void dispose() {
    unawaited(_routeSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return AdaptiveTheme(
      light: lightTheme,
      dark: darkTheme,
      initial: widget.theme ?? AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => MaterialApp.router(
        routerConfig: router,
        scrollBehavior: AppScrollBehavior(),
        title: 'الطريقة اليسرية',
        debugShowCheckedModeBanner: false,
        darkTheme: darkTheme,
        theme: theme,
      ),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
