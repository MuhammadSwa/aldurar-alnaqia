import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:aldurar_alnaqia/common/theme/app_theme.dart';
import 'package:aldurar_alnaqia/router/app_router.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart' show RoutePaths;
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/common/helpers/app_platform.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/audio_engine.dart';
import 'package:aldurar_alnaqia/audio/audio_handler.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/services/prayer_notification_service.dart';
import 'package:aldurar_alnaqia/common/helpers/logger.dart';

Future<ProviderContainer> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Media notification + background audio (mobile). Requires the
  // audio_service entries in AndroidManifest.xml and the iOS audio
  // background mode.
  NarrationAudioHandler? audioHandler;
  if (AppPlatform.isMobile) {
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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );

  // Defer non-critical platform work (notification channel, permission
  // prompt, foreground service) until after the first frame so the UI
  // paints immediately instead of showing a white splash on Android.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_startPlatformServices());
  });
}

/// Notification permission + the native prayer-countdown foreground service
/// bridge (Android only).
Future<void> _startPlatformServices() async {
  try {
    await initializePrayerNotifications();
  } catch (e, st) {
    logError('Deferred platform service startup failed', e, st);
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

bool _isAllowedNotificationRoute(String route) {
  return route == RoutePaths.timings ||
      route == RoutePaths.home ||
      route == RoutePaths.awrad ||
      route == RoutePaths.library ||
      route == RoutePaths.social ||
      route.startsWith('${RoutePaths.downloadManager}/');
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription<String>? _routeSub;

  @override
  void initState() {
    super.initState();
    // The native prayer notification asks us to navigate when the user taps
    // it (cold start included — Android buffers the tap until we're ready).
    // Only allow known in-app locations; anything else is ignored so a
    // compromised/malformed channel message can't drive us to an arbitrary
    // location.
    _routeSub = onNotificationRouteTap.listen((route) {
      if (!_isAllowedNotificationRoute(route)) {
        logWarn('Ignoring notification route: $route');
        return;
      }
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
    final themeMode = ref.watch(themeModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    return MaterialApp.router(
      routerConfig: router,
      scrollBehavior: AppScrollBehavior(),
      title: 'الطريقة اليسرية',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(fontSize: fontSize),
      darkTheme: AppTheme.dark(fontSize: fontSize),
      themeMode: themeMode,
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
