import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/router/app_router.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/widgets/main_wrapper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No track loaded: the mini player stays hidden and just_audio untouched.
class _IdleAudio extends AudioController {
  @override
  AudioState build() => const AudioState();
}

const List<String> _tabs = [
  RoutePaths.home,
  RoutePaths.timings,
  RoutePaths.awrad,
  RoutePaths.library,
];

/// The app's tab shell around stand-in screens, each tab with a screen
/// pushed inside it at `<tab>/inner`.
GoRouter _router() => GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        StatefulShellRoute(
          pageBuilder: (context, state, navigationShell) =>
              MaterialPage(child: navigationShell),
          navigatorContainerBuilder: (context, navigationShell, children) =>
              MainWrapper(
            navigationShell: navigationShell,
            isTabRoot: AppRouter.isTabRoot(
              navigationShell.shellRouteContext.routerState.uri,
            ),
            children: children,
          ),
          branches: [
            for (final tab in _tabs)
              StatefulShellBranch(
                preload: true,
                routes: [
                  GoRoute(
                    path: tab,
                    builder: (context, state) => _Screen(tab),
                    routes: [
                      GoRoute(
                        path: 'inner',
                        builder: (context, state) => _Screen('$tab/inner'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ],
    );

class _Screen extends StatelessWidget {
  const _Screen(this.name);

  final String name;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(name)));
}

Future<GoRouter> _pumpShell(WidgetTester tester) async {
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [audioProvider.overrideWith(_IdleAudio.new)],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

int _selectedTab(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

bool _isOpenTab(WidgetTester tester, String tab) =>
    TickerMode.valuesOf(tester.element(find.text(tab))).enabled;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferencesService().init();
  });

  // In the Arabic layout the tabs run right to left, like the
  // NavigationBar: the next tab is to the left, brought in by a swipe to
  // the right. The drawer is on the right, past home.

  testWidgets('swiping moves between tabs and switches branch',
      (tester) async {
    final router = await _pumpShell(tester);

    await tester.fling(
      find.text(RoutePaths.home),
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(_location(router), RoutePaths.timings);
    expect(_selectedTab(tester), 1);
    expect(find.text(RoutePaths.home), findsNothing);
    expect(_isOpenTab(tester, RoutePaths.timings), isTrue);

    await tester.fling(
      find.text(RoutePaths.timings),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(_location(router), RoutePaths.home);
    expect(_selectedTab(tester), 0);
    // Only swiping past home itself opens the drawer.
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('a peek at the next tab that swipes back stays on the tab',
      (tester) async {
    final router = await _pumpShell(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text(RoutePaths.home)),
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    // In view, but not the open tab until a swipe settles on it.
    expect(find.text(RoutePaths.timings), findsOneWidget);
    expect(_isOpenTab(tester, RoutePaths.timings), isFalse);

    await gesture.moveBy(const Offset(-200, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_location(router), RoutePaths.home);
    expect(_selectedTab(tester), 0);
    expect(_isOpenTab(tester, RoutePaths.home), isTrue);
  });

  testWidgets('swiping past home pulls out the drawer under the finger',
      (tester) async {
    final router = await _pumpShell(tester);
    final screenWidth = tester.getSize(find.byType(MainWrapper)).width;

    final gesture = await tester.startGesture(
      tester.getCenter(find.text(RoutePaths.home)),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    final halfway = tester.getRect(find.byType(Drawer));
    expect(halfway.left, greaterThan(screenWidth - halfway.width));
    expect(halfway.left, lessThan(screenWidth));

    await gesture.moveBy(const Offset(-100, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    final open = tester.getRect(find.byType(Drawer));
    expect(open.right, screenWidth);
    expect(open.left, screenWidth - open.width);
    expect(_location(router), RoutePaths.home);

    // The back button closes it, and stays on home.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(_location(router), RoutePaths.home);
  });

  testWidgets('a short pull on the drawer lets it slide back', (tester) async {
    await _pumpShell(tester);

    await tester.drag(find.text(RoutePaths.home), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('the scrim closes the drawer', (tester) async {
    await _pumpShell(tester);

    await tester.drag(find.text(RoutePaths.home), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);

    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('tapping a tab or navigating elsewhere moves the pager',
      (tester) async {
    final router = await _pumpShell(tester);

    await tester.tap(find.text('المكتبة'));
    await tester.pumpAndSettle();
    expect(_location(router), RoutePaths.library);
    expect(find.text(RoutePaths.library), findsOneWidget);
    expect(find.text(RoutePaths.home), findsNothing);

    router.go(RoutePaths.awrad);
    await tester.pumpAndSettle();
    expect(_selectedTab(tester), 2);
    expect(find.text(RoutePaths.awrad), findsOneWidget);
    expect(find.text(RoutePaths.library), findsNothing);
  });

  testWidgets('a screen pushed inside a tab keeps the swipe for itself',
      (tester) async {
    final router = await _pumpShell(tester);
    router.go('${RoutePaths.home}/inner');
    await tester.pumpAndSettle();

    await tester.fling(
      find.text('${RoutePaths.home}/inner'),
      const Offset(300, 0),
      1000,
    );
    await tester.drag(
      find.text('${RoutePaths.home}/inner'),
      const Offset(-250, 0),
    );
    await tester.pumpAndSettle();
    expect(_location(router), '${RoutePaths.home}/inner');
    expect(find.byType(Drawer), findsNothing);
  });
}
