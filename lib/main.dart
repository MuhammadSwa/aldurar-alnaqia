import 'dart:async';
import 'dart:ui';

import 'package:aldurar_alnaqia/common/helpers/app_platform.dart';
import 'package:aldurar_alnaqia/common/helpers/logger.dart';
import 'package:aldurar_alnaqia/common/theme/app_theme.dart';
import 'package:aldurar_alnaqia/router/app_router.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart' show RoutePaths;
import 'package:aldurar_alnaqia/services/prayer_notification_service.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

Future<ProviderContainer> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Media notification + background audio (mobile). just_audio_background
  // drives the native audio_service infrastructure already configured
  // (AndroidManifest service entry, iOS background mode) — no platform
  // changes required.
  if (AppPlatform.isMobile) {
    await JustAudioBackground.init(
      androidNotificationChannelId:
          'com.example.aldurar_alnaqia.channel.audio',
      androidNotificationChannelName: 'تشغيل الصوت',
      androidNotificationChannelDescription: 'التحكم بتشغيل التلاوات',
    );
  }

  await SharedPreferencesService().init();

  // Prayer math needs the IANA database (synchronous; block startup — every
  // prayer read below depends on it, and prefs are already awaited).
  tzdata.initializeTimeZones();

  final container = ProviderContainer(
    overrides: [
      storageProvider.overrideWithValue(await StorageService().init()),
    ],
  );

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
  final GoRouter _router = AppRouter.createRouter();
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
      _router.go(route);
    });
  }

  @override
  void dispose() {
    unawaited(_routeSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    return MaterialApp.router(
      routerConfig: _router,
      restorationScopeId: 'app',
      //
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      //
      scrollBehavior: AppScrollBehavior(),
      title: 'الدرر النقية',
      debugShowCheckedModeBanner: false,
      //
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
