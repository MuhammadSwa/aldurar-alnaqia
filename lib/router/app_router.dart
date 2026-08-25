import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/widgets/collection_screens.dart';
import 'package:aldurar_alnaqia/widgets/main_wrapper.dart';
import 'package:aldurar_alnaqia/widgets/week_azkar_list.dart';
import 'package:aldurar_alnaqia/screens/home_screen/home_screen.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_screen.dart';
import 'package:aldurar_alnaqia/screens/award_list_screen/awrad_list_screen.dart';
import 'package:aldurar_alnaqia/screens/library_screen/library_screen.dart';
import 'package:aldurar_alnaqia/screens/library_screen/pdf_viewer_widget.dart';
import 'package:aldurar_alnaqia/screens/social_screen/social_screen.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_manager_screen.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/zikr_screen.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/helia_nasab_screen.dart';
import 'package:aldurar_alnaqia/models/consts/alhadra_collection.dart';
import 'package:aldurar_alnaqia/models/consts/orphans.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart'
    show islamicWeekdayNow;

/// Provides the app-wide [GoRouter]. The app always starts at home;
/// notification taps navigate via `go()` after startup.
final appRouterProvider = Provider<GoRouter>((ref) {
  return AppRouter.createRouter();
});

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRouter {
  AppRouter._();

  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: RoutePaths.home,
      debugLogDiagnostics: true,
      navigatorKey: _rootNavigatorKey,
      routes: [
        // Standalone routes (not in bottom nav)
        _createSocialRoute(),
        _createDownloadManagerRoute(),

        // Bottom navigation shell with main tabs
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainWrapper(navigationShell: navigationShell);
          },
          branches: [
            _createHomeBranch(),
            _createPrayerTimingsBranch(),
            _createAwradBranch(),
            _createLibraryBranch(),
          ],
        ),
      ],
    );
  }

  // --- Standalone routes ---------------------------------------------------

  static GoRoute _createSocialRoute() {
    return GoRoute(
      path: RoutePaths.social,
      builder: (context, state) => const SocialScreen(),
    );
  }

  static GoRoute _createDownloadManagerRoute() {
    return GoRoute(
      path: '${RoutePaths.downloadManager}/:index',
      builder: (context, state) {
        final index = int.parse(state.pathParameters['index']!);
        return DownloadManagerPage(initialIndex: index);
      },
    );
  }

  // --- Bottom navigation branches -------------------------------------------

  static StatefulShellBranch _createHomeBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: RoutePaths.home,
          name: RouteNames.home,
          builder: (context, state) => const HomePage(),
          routes: [
            _createTodayZikrRoute(),
            _createWeekCollectionRoute(ZikrBranch.home),
            _createZikrCollectionRoute(ZikrBranch.home),
            _createZikrPageRoute(ZikrBranch.home, pagePrefix: 'home'),
          ],
        ),
      ],
    );
  }

  static StatefulShellBranch _createPrayerTimingsBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: RoutePaths.timings,
          name: RouteNames.timings,
          builder: (context, state) => const PrayerTimingsScreen(),
        ),
      ],
    );
  }

  static StatefulShellBranch _createAwradBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: RoutePaths.awrad,
          name: RouteNames.awrad,
          builder: (context, state) => const AwradListScreen(),
          routes: [
            _createWeekCollectionRoute(ZikrBranch.awrad),
            _createZikrCollectionRoute(ZikrBranch.awrad),
            _createZikrPageRoute(ZikrBranch.awrad, pagePrefix: 'awrad'),
            _createHeliaNasabRoute(),
          ],
        ),
      ],
    );
  }

  static StatefulShellBranch _createLibraryBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: RoutePaths.library,
          name: RouteNames.library,
          builder: (context, state) => const LibraryScreen(),
          routes: [
            _createPdfViewerRoute(),
          ],
        ),
      ],
    );
  }

  // --- Nested content routes -------------------------------------------------
  //
  // Path parameters are read RAW from state.pathParameters: go_router has
  // already percent-decoded them. Never decode again here.

  static GoRoute _createTodayZikrRoute() {
    return GoRoute(
      path: RoutePaths.todaysZikrSegment,
      name: RouteNames.todayZikr,
      pageBuilder: (context, state) {
        return RouteTransitions.slideTransition(
          DayAzkarList(
            dayNum: islamicWeekdayNow(),
            branch: ZikrBranch.home,
            detailPagePrefix: RouteNames.todayZikrPagePrefix,
          ),
        );
      },
      routes: [_createZikrPageRoute(ZikrBranch.home, pagePrefix: RouteNames.todayZikrPagePrefix)],
    );
  }

  static GoRoute _createWeekCollectionRoute(ZikrBranch branch) {
    return GoRoute(
      path: RoutePaths.weekCollectionSegment,
      name: RouteNames.weekCollection(branch),
      pageBuilder: (context, state) {
        return RouteTransitions.slideTransition(
          WeekCollectionScreen(branch: branch),
        );
      },
      routes: _createDayCollectionRoutes(branch),
    );
  }

  static List<GoRoute> _createDayCollectionRoutes(ZikrBranch branch) {
    return List.generate(8, (index) {
      final pagePrefix = RouteNames.weekCollectionDay(branch, index);
      return GoRoute(
        path: index.toString(),
        pageBuilder: (context, state) {
          return RouteTransitions.slideTransition(
            DayAzkarList(
              dayNum: index,
              branch: branch,
              detailPagePrefix: pagePrefix,
            ),
          );
        },
        routes: [
          _createZikrPageRoute(branch, pagePrefix: pagePrefix),
        ],
      );
    });
  }

  static GoRoute _createZikrCollectionRoute(ZikrBranch branch) {
    return GoRoute(
      path: RoutePaths.zikrCollectionSegment,
      name: RouteNames.zikrCollection(branch),
      pageBuilder: (context, state) {
        final collection = state.pathParameters['collection']!;
        final azkarTitles = azkarCollections.getAzkarTitles(collection);

        return RouteTransitions.slideTransition(
          ZikrCollectionScreen(
            branch: branch,
            collection: collection,
            azkarTitles: azkarTitles,
          ),
        );
      },
      routes: [
        _createZikrPageRoute(
          branch,
          pagePrefix: RouteNames.zikrCollection(branch),
        ),
      ],
    );
  }

  static GoRoute _createZikrPageRoute(
    ZikrBranch branch, {
    required String pagePrefix,
  }) {
    return GoRoute(
      path: RoutePaths.zikrSegment,
      name: RouteNames.zikrPage(pagePrefix),
      pageBuilder: (context, state) {
        final zikr = state.pathParameters['zikr']!;

        final (titles, index) = _parseZikrExtras(state.extra);

        // Handle special standalone compositions
        if (zikr == alhyliaAndNasab.title) {
          return RouteTransitions.slideTransition(const HeliaNasabScreen());
        }
        if (zikr == sanadAltareeqa.title) {
          return RouteTransitions.slideTransition(const TareeqaSanadScreen());
        }

        return RouteTransitions.slideTransition(
          ZikrScreen(title: zikr, titles: titles, index: index),
        );
      },
    );
  }

  static GoRoute _createHeliaNasabRoute() {
    return GoRoute(
      path: 'heliaNasab',
      name: RouteNames.heliaNasab,
      pageBuilder: (context, state) {
        return RouteTransitions.slideTransition(const HeliaNasabScreen());
      },
    );
  }

  static GoRoute _createPdfViewerRoute() {
    return GoRoute(
      path: 'pdfViewer/:bookTitle',
      name: RouteNames.pdfViewer,
      builder: (context, state) {
        final bookTitle = state.pathParameters['bookTitle']!;
        return PdfviewerWidget(title: bookTitle);
      },
    );
  }

  /// Typed extras parsing for zikr detail pages. Accepts both the typed
  /// [ZikrRouteExtra] and legacy map extras.
  static (List<String>?, int?) _parseZikrExtras(Object? extra) {
    if (extra is ZikrRouteExtra) {
      return (extra.titles, extra.index);
    }
    if (extra is Map) {
      final t = extra['titles'];
      final i = extra['index'];
      final titles = t is List ? t.whereType<String>().toList() : null;
      final index = i is int ? i : null;
      return (titles, index);
    }
    return (null, null);
  }
}

// router/route_transitions.dart

class RouteTransitions {
  RouteTransitions._();

  static CustomTransitionPage<Widget> slideTransition(Widget child) {
    return CustomTransitionPage<Widget>(
      child: child,
      transitionsBuilder: _slideTransition,
    );
  }

  static Widget _slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubicEmphasized,
        ),
      ),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}
