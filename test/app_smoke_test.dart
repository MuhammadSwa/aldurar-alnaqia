import 'dart:ui';

import 'package:aldurar_alnaqia/common/theme/app_theme.dart';
import 'package:aldurar_alnaqia/main.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// App-level smoke tests: cheap contracts owned by main.dart wiring that no
// other test covers (replaces the old placeholder widget_test.dart which
// pumped a bare Text('smoke') and asserted nothing about the app).
void main() {
  group('AppScrollBehavior', () {
    test('supports touch, mouse, and trackpad drags', () {
      expect(
        AppScrollBehavior().dragDevices,
        containsAll({
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        }),
      );
    });
  });

  group('top-level route contract', () {
    test('paths are absolute, ASCII, and unique', () {
      const paths = [
        RoutePaths.home,
        RoutePaths.timings,
        RoutePaths.awrad,
        RoutePaths.library,
        RoutePaths.social,
        RoutePaths.downloadManager,
      ];
      for (final path in paths) {
        expect(path, startsWith('/'));
        expect(path, matches(RegExp(r'^[\x00-\x7F]+$')));
      }
      expect(paths.toSet(), hasLength(paths.length));
    });

    test('notification allowlist targets stay in sync with RoutePaths', () {
      // _isAllowedNotificationRoute in main.dart gates notification taps to
      // these locations; if a path is renamed, navigation silently stops.
      expect(RoutePaths.timings, '/timings');
      expect(RoutePaths.home, '/home');
      expect(RoutePaths.awrad, '/awradScreen');
      expect(RoutePaths.library, '/library');
      expect(RoutePaths.social, '/social');
      expect(
        AppRoutes.downloadManager(0),
        startsWith('${RoutePaths.downloadManager}/'),
      );
    });
  });

  group('theme default contract', () {
    test('AppTheme default font size matches fresh prefs default', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPreferencesService().init();
      expect(
        AppTheme.defaultFontSize,
        SharedPreferencesService.getFontSize(),
      );
    });
  });

  group('AudioDetachObserver', () {
    test('stops playback when the app is detached (swiped away)', () {
      var stops = 0;
      AudioDetachObserver(() async => stops++)
          .didChangeAppLifecycleState(AppLifecycleState.detached);

      expect(stops, 1);
    });

    test('ignores non-detach states so background playback survives', () {
      var stops = 0;
      final observer = AudioDetachObserver(() async => stops++);

      AppLifecycleState.values
          .where((s) => s != AppLifecycleState.detached)
          .forEach(observer.didChangeAppLifecycleState);

      expect(stops, 0);
    });
  });
}
