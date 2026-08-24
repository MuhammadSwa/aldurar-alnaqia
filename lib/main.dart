import 'dart:ui';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:aldurar_alnaqia/common/theme/dark_theme.dart';
import 'package:aldurar_alnaqia/router/app_router.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:desktop_window/desktop_window.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/audio_engine.dart';
import 'package:aldurar_alnaqia/audio/audio_handler.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/services/prayer_foreground_service.dart';
import 'package:aldurar_alnaqia/services/notification_helper.dart';

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

  // Create notification channel and request permission (Android 13+)
  await NotificationHelper.initialize();
  // Start persistent foreground notification with next prayer countdown (Android only)
  await initializePrayerForegroundService();

  return container;
}

Future<void> main() async {
  final container = await _bootstrap();

  // Choose initial route based on a hint from notification tap
  String? initialLocation;
  try {
    final sp = await SharedPreferences.getInstance();
    final hint = sp.getString('initial_route_hint');
    if (hint != null && hint.isNotEmpty) {
      initialLocation = hint;
      await sp.remove('initial_route_hint');
    }
  } catch (_) {}

  final savedThemeMode = await AdaptiveTheme.getThemeMode();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MyApp(theme: savedThemeMode, initialLocation: initialLocation),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key, required this.theme, this.initialLocation});
  final AdaptiveThemeMode? theme;
  final String? initialLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider(initialLocation));
    return AdaptiveTheme(
      light: lightTheme,
      dark: darkTheme,
      initial: theme ?? AdaptiveThemeMode.system,
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
