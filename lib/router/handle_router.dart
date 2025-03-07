import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yosria/router/zikrCollection_route.dart';
import 'package:yosria/router/zikrPage_router.dart';
import 'package:yosria/screens/download_manager_screen/download_manager_screen.dart';
import 'package:yosria/screens/library_screen/library_screen.dart';
import 'package:yosria/screens/library_screen/pdf_viewer_widget.dart';
import 'package:yosria/screens/social_screen/social_screen.dart';
import 'package:yosria/widgets/azkarListView/helia_nasab_screen.dart';
import 'package:yosria/widgets/main_wrapper.dart';
import 'package:yosria/router/page_transitions.dart';
import 'package:yosria/router/todayZikrRoute.dart';
import 'package:yosria/router/week_collection_router.dart';
import 'package:yosria/screens/prayer_timings_screen/prayer_timings_screen.dart';
import 'package:yosria/screens/award_list_screen/awrad_list_screen.dart';
import 'package:yosria/screens/home_screen/home_screen.dart';
import 'package:yosria/screens/settings_screen/settings_screen.dart';
import 'package:yosria/widgets/zikrSlider_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
// final GlobalKey<NavigatorState> _shellNavigatorKey =
//     GlobalKey<NavigatorState>(debugLabel: 'shell');

GoRouter handleRouter() {
  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: true,
    navigatorKey: _rootNavigatorKey,
    routes: [
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) {
          return const SettingsScreen();
        },
      ),
      GoRoute(
        path: '/social',
        builder: (BuildContext context, GoRouterState state) {
          return const SocialScreen();
        },
      ),
      GoRoute(
          path: '/downloadManager/:index',
          builder: (BuildContext context, GoRouterState state) {
            final index = int.parse(state.pathParameters['index']!);
            return DownloadManagerPage(index: index);
          }),
      GoRoute(
          path: '/slider',
          builder: (BuildContext context, GoRouterState state) {
            final titles = state.extra as List<String>;
            return ZikrsliderScreen(titles);
          }),

      // bottomNavigation nested routes.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainWrapper(
            navigationShell: navigationShell,
          );
        },
        branches: <StatefulShellBranch>[
          // Branch Home
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (BuildContext context, GoRouterState state) =>
                  const HomePage(),
              routes: [
                zikrPageRoute(),
                zikrCollectionRoute(parent: 'home'),

                todayZikrRoute(),

                weekCollectionRouter(parent: 'home'),
                ...dayCollectionroute(parent: 'home'),
                // TODO: make it work of helia+nasab
                // _zikrImgsRoute(parent: '/home')
              ],
            )
          ]),
          // prayer_timings_screen
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/timings',
                  builder: (context, state) => const PrayerTimingsScreen()),
            ],
          ),
// third screen
          // StatefulShellBranch(
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/awradScreen',
                name: '/awradScreen',
                builder: (BuildContext context, GoRouterState state) =>
                    const AwradListScreen(),
                routes: [
                  weekCollectionRouter(parent: 'awradScreen'),
                  zikrCollectionRoute(parent: 'awradScreen'),
                  zikrPageRoute(),
                  GoRoute(
                      path: 'heliaNasab',
                      name: 'awradScreen/heliaNasab',
                      pageBuilder: (context, state) {
                        return handleHeliaNasab();
                      }),
                ],
              )
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/library',
                  name: 'library',
                  builder: (BuildContext context, GoRouterState state) =>
                      const LibraryScreen(),
                  routes: [
                    GoRoute(
                        path: 'pdfViewer/:bookTitle',
                        name: 'pdfViewer/:bookTitle',
                        builder: (context, state) {
                          final bookTitle = state.pathParameters['bookTitle']!;
                          return PdfviewerWidget(title: bookTitle);
                        })
                  ])
            ],
          ),

          // StatefulShellBranch(
          //   routes: [
          //     GoRoute(
          //       path: '/about',
          //       name: 'about',
          //       builder: (BuildContext context, GoRouterState state) =>
          //           const AboutTareeqaScreen(),
          //     )
          //   ],
          // ),
        ],
      )
    ],
  );
}

CustomTransitionPage<Widget> handleHeliaNasab() {
  return const CustomTransitionPage<Widget>(
    child: HeliaNasabScreen(),
    // HeliaNasabScreen(),
    transitionsBuilder: slideTransition,
  );
}

CustomTransitionPage<Widget> handleSanadTareeqa() {
  return const CustomTransitionPage<Widget>(
    child: TareeqaSanadScreen(),
    // HeliaNasabScreen(),
    transitionsBuilder: slideTransition,
  );
}
