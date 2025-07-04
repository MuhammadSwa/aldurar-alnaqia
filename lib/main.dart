import 'dart:io';
import 'dart:ui';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:aldurar_alnaqia/audioPlayer/audioPlayer.dart';
import 'package:aldurar_alnaqia/audioPlayer/audio_handler.dart';
import 'package:aldurar_alnaqia/services/prayer_notification_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:aldurar_alnaqia/common/theme/dark_theme.dart';
import 'package:aldurar_alnaqia/router/handle_router.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:get/get.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:desktop_window/desktop_window.dart';

Future setDesktopWindow() async {
  await DesktopWindow.setMinWindowSize(const Size(600, 600));
  await DesktopWindow.setWindowSize(const Size(1300, 900));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (UniversalPlatform.isDesktop) {
    setDesktopWindow();
  }

  // We need to initialize the audio handler before running the app.
  // We also register it with GetX so we can find it later.

  final audioHandler = await initAudioService();
  Get.put<AudioHandler>(audioHandler);
  Get.put<Controller>(Controller(), permanent: true);
  // }

  await SharedPreferencesService().init();

  if (UniversalPlatform.isAndroid) {
    await PrayerNotificationService.initialize();
  }

  final savedThemeMode = await AdaptiveTheme.getThemeMode();

  runApp(
    MyApp(theme: savedThemeMode),
  );
}

class MyApp extends StatelessWidget {
  MyApp({super.key, required this.theme});
  final AdaptiveThemeMode? theme;

  final _router = AppRouter.createRouter();

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: lightTheme,
      dark: darkTheme,
      initial: theme ?? AdaptiveThemeMode.system,
      // TODO: change routing to Getx
      builder: (theme, darkTheme) => MaterialApp.router(
        routerConfig: _router,
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
