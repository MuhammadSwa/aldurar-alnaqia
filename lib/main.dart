import 'dart:ui';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:aldurar_alnaqia/common/theme/dark_theme.dart';
import 'package:aldurar_alnaqia/router/handle_router.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:desktop_window/desktop_window.dart';
import 'package:get/get.dart';
import 'package:aldurar_alnaqia/audioPlayer/audioPlayer.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';
import 'package:aldurar_alnaqia/widgets/main_wrapper.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/font_settings_widget.dart';
import 'package:aldurar_alnaqia/services/prayer_foreground_service.dart';
import 'package:aldurar_alnaqia/services/notification_helper.dart';
import 'package:go_router/go_router.dart';

Future setDesktopWindow() async {
  await DesktopWindow.setMinWindowSize(const Size(600, 600));
  await DesktopWindow.setWindowSize(const Size(1300, 900));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (UniversalPlatform.isWindows ||
      UniversalPlatform.isLinux ||
      UniversalPlatform.isMacOS) {
    await setDesktopWindow();
  }

  await SharedPreferencesService().init();
  await Get.put(StorageService(), permanent: true).init();
  final savedThemeMode = await AdaptiveTheme.getThemeMode();

  // Register long-lived controllers/services
  Get.put(Controller(), permanent: true);
  Get.put(DownloaderController(), permanent: true);
  Get.put(PrayerTimingsController(), permanent: true);
  Get.put(GlobalDrawerController(), permanent: true);
  Get.put(FontController(), permanent: true);

  // if (Platform.isAndroid) {
  //   await PrayerNotificationService.initialize();
  // }

  // Create notification channel and request permission (Android 13+)
  await NotificationHelper.initialize();
  // Start persistent foreground notification with next prayer countdown (Android only)
  await initializePrayerForegroundService();

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

  runApp(
    MyApp(theme: savedThemeMode, initialLocation: initialLocation),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.theme, this.initialLocation});
  final AdaptiveThemeMode? theme;
  final String? initialLocation;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = AppRouter.createRouter(initialLocation: widget.initialLocation);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // When resuming from notification tap while app is in background
      final sp = await SharedPreferences.getInstance();
      final hint = sp.getString('initial_route_hint');
      if (hint != null && hint.isNotEmpty) {
        await sp.remove('initial_route_hint');
        if (mounted) {
          AppRouter.goTo(hint);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure DI exists even when MyApp is directly pumped in tests (main() not run)
    if (!Get.isRegistered<Controller>()) {
      Get.put(Controller(), permanent: true);
    }
    if (!Get.isRegistered<DownloaderController>()) {
      Get.put(DownloaderController(), permanent: true);
    }
    if (!Get.isRegistered<PrayerTimingsController>()) {
      Get.put(PrayerTimingsController(), permanent: true);
    }
    if (!Get.isRegistered<GlobalDrawerController>()) {
      Get.put(GlobalDrawerController(), permanent: true);
    }
    if (!Get.isRegistered<FontController>()) {
      Get.put(FontController(), permanent: true);
    }

    final router = _router;
    return AdaptiveTheme(
      light: lightTheme,
      dark: darkTheme,
  initial: widget.theme ?? AdaptiveThemeMode.system,
      // TODO: change routing to Getx
      builder: (theme, darkTheme) => MaterialApp.router(
        routerConfig: router,
        scrollBehavior: AppScrollBehavior(),
        title: 'الطريقة اليسرية',
        debugShowCheckedModeBanner: false,
        darkTheme: darkTheme,
        theme: theme,
      ),
      // ),
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
