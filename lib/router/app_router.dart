import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/prayer/prayer_repository.dart'
    show islamicWeekdayNow;
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/router/swipe_back.dart';
import 'package:aldurar_alnaqia/screens/awrad_list_screen/awrad_list_screen.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_manager_screen.dart';
import 'package:aldurar_alnaqia/screens/home_screen/home_screen.dart';
import 'package:aldurar_alnaqia/screens/library_screen/book_viewer_screen.dart';
import 'package:aldurar_alnaqia/screens/library_screen/library_screen.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_screen.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_settings_screen.dart';
import 'package:aldurar_alnaqia/screens/social_screen/social_screen.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/zikr_screen.dart';
import 'package:aldurar_alnaqia/widgets/collection_screens.dart';
import 'package:aldurar_alnaqia/widgets/main_wrapper.dart';
import 'package:aldurar_alnaqia/widgets/week_azkar_list.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRouter {
  AppRouter._();

  /// Creates the app-wide [GoRouter]. The app always starts at home;
  /// notification taps navigate via `go()` after startup.
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: RoutePaths.home,
      debugLogDiagnostics: kDebugMode,
      navigatorKey: _rootNavigatorKey,
      restorationScopeId: 'router',
      routes: [
        // Standalone fullscreen routes (above the bottom-nav shell, so
        // they take the full screen with no NavigationBar).
        _createSocialRoute(),
        _createDownloadManagerRoute(),
        _createPdfViewerRoute(),

        // Bottom navigation shell with main tabs. MainWrapper lays the
        // branches out side by side in a pager, so a swipe moves between
        // tabs. Every branch is preloaded so a tab swiped into view shows
        // its screen, not an empty page; the pager still builds that screen
        // only once it comes into view.
        StatefulShellRoute(
          restorationScopeId: 'appShell',
          pageBuilder: (context, state, navigationShell) {
            return MaterialPage(
              key: state.pageKey,
              restorationId: 'appShellPage',
              child: navigationShell,
            );
          },
          navigatorContainerBuilder: (context, navigationShell, children) {
            return MainWrapper(
              navigationShell: navigationShell,
              isTabRoot:
                  isTabRoot(navigationShell.shellRouteContext.routerState.uri),
              children: children,
            );
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

  static const Set<String> _tabRootPaths = {
    RoutePaths.home,
    RoutePaths.timings,
    RoutePaths.awrad,
    RoutePaths.library,
  };

  /// Whether [location] is a bottom-nav tab's own screen rather than one
  /// pushed inside it. Only there does a swipe move between tabs (and, from
  /// home, open the drawer); everywhere else the swipe goes back.
  static bool isTabRoot(Uri location) =>
      _tabRootPaths.contains(location.path);

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
        final index = int.tryParse(state.pathParameters['index'] ?? '') ?? 0;
        final safeIndex = index.clamp(0, 1);
        return DownloadManagerPage(initialIndex: safeIndex);
      },
    );
  }

  // --- Bottom navigation branches -------------------------------------------

  static StatefulShellBranch _createHomeBranch() {
    return StatefulShellBranch(
      restorationScopeId: 'homeBranch',
      preload: true,
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
      restorationScopeId: 'timingsBranch',
      preload: true,
      routes: [
        GoRoute(
          path: RoutePaths.timings,
          name: RouteNames.timings,
          builder: (context, state) => const PrayerTimingsScreen(),
          routes: [
            _createTimingsSettingsRoute(),
          ],
        ),
      ],
    );
  }

  /// Settings page nested under the timings branch so re-tapping the
  /// prayers bottom-nav destination pops back to `/timings`
  /// (`goBranch(initialLocation: true)` only resets go_router locations —
  /// an imperative `Navigator.push` bypasses it and gets stuck).
  static GoRoute _createTimingsSettingsRoute() {
    return GoRoute(
      path: RoutePaths.timingsSettingsSegment,
      name: RouteNames.timingsSettings,
      pageBuilder: (context, state) {
        return RouteTransitions.slideTransition(
          const PrayerTimingsSettingsScreen(),
          key: state.pageKey,
          restorationId: 'timingsSettings',
        );
      },
    );
  }

  static StatefulShellBranch _createAwradBranch() {
    return StatefulShellBranch(
      restorationScopeId: 'awradBranch',
      preload: true,
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
      restorationScopeId: 'libraryBranch',
      preload: true,
      routes: [
        GoRoute(
          path: RoutePaths.library,
          name: RouteNames.library,
          builder: (context, state) => const LibraryScreen(),
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
          key: state.pageKey,
          restorationId: 'todayZikr',
        );
      },
      routes: [
        _createZikrPageRoute(ZikrBranch.home,
            pagePrefix: RouteNames.todayZikrPagePrefix)
      ],
    );
  }

  static GoRoute _createWeekCollectionRoute(ZikrBranch branch) {
    return GoRoute(
      path: RoutePaths.weekCollectionSegment,
      name: RouteNames.weekCollection(branch),
      pageBuilder: (context, state) {
        return RouteTransitions.slideTransition(
          WeekCollectionScreen(branch: branch),
          key: state.pageKey,
          restorationId: 'weekCollection-${branch.name}',
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
            key: state.pageKey,
            restorationId: 'dayCollection-${branch.name}-$index',
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
        final collectionId = state.pathParameters['collection']!;
        final collection = resolveCollection(collectionId);
        final collectionTitle = collection?.title ?? collectionId;
        final zikrIds = collectionZikrIds(collectionId);

        return RouteTransitions.slideTransition(
          ZikrCollectionScreen(
            branch: branch,
            collection: collectionTitle,
            collectionId: collection?.id ?? collectionId,
            zikrIds: zikrIds,
          ),
          key: state.pageKey,
          restorationId: 'zikrCollection-${branch.name}',
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
      // Keep the branch's URL and back stack, but render the reader above
      // the shell just like the PDF viewer. This removes NavigationBar while
      // preserving the shell underneath for a normal back navigation.
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.zikrSegment,
      name: RouteNames.zikrPage(pagePrefix),
      pageBuilder: (context, state) {
        final zikrId = state.pathParameters['zikr']!;

        final (zikrIds, index) =
            _resolveSwipeContext(state.extra, state.uri, zikrId);

        // With swipe context (ids + index) the reader swipes across the
        // list; without it (search, deep links) it shows the zikr alone.
        // Either way it renders special compositions like Hilya/Sanad.
        return RouteTransitions.slideTransition(
          AudioMiniPlayerOverlay(
            child: ZikrScreen(
              zikrId: zikrId,
              zikrIds: zikrIds,
              index: index,
            ),
          ),
          key: state.pageKey,
          restorationId: 'zikrPage-$pagePrefix',
          swipeBack: false,
        );
      },
    );
  }

  static GoRoute _createHeliaNasabRoute() {
    return GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: 'heliaNasab',
      name: RouteNames.heliaNasab,
      pageBuilder: (context, state) {
        return RouteTransitions.slideTransition(
          const AudioMiniPlayerOverlay(
            child: ZikrScreen(zikrId: 'hilya-nasab'),
          ),
          key: state.pageKey,
          restorationId: 'heliaNasab',
          swipeBack: false,
        );
      },
    );
  }

  /// Fullscreen reader (uses AppPdfView): kept at the root level — not
  /// nested in the bottom-nav shell — so the book takes the full screen
  /// with no NavigationBar. The URL stays `/library/pdfViewer/:bookId` so
  /// existing deep links and AppRoutes.pdfViewerPath keep working.
  static GoRoute _createPdfViewerRoute() {
    return GoRoute(
      path: '${RoutePaths.library}/pdfViewer/:bookId',
      name: RouteNames.pdfViewer,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final bookId = state.pathParameters['bookId']!;
        return BookViewerScreen(bookId: bookId);
      },
    );
  }

  /// Swipe context for zikr detail pages. Fast path is the typed
  /// [ZikrRouteExtra]; when that is gone (OS process death — `extra` is
  /// not serialized, only the URL is), fall back to the `ids`+`i` query
  /// params written by [ZikrDetailTarget.go]. Anything unparseable or
  /// inconsistent carries no swipe context.
  static (List<String>?, int?) _resolveSwipeContext(
    Object? extra,
    Uri uri,
    String zikrId,
  ) {
    if (extra is ZikrRouteExtra) {
      return (extra.zikrIds, extra.index);
    }
    final rawIds = uri.queryParameters['ids'];
    final rawIndex = uri.queryParameters['i'];
    if (rawIds == null || rawIds.isEmpty || rawIndex == null) {
      return (null, null);
    }
    // Guard against hand-crafted deep links with huge payloads.
    if (rawIds.length > 4000) return (null, null);
    final ids = rawIds.split(',').where((s) => s.isNotEmpty).toList();
    final index = int.tryParse(rawIndex);
    if (ids.isEmpty ||
        ids.length > 200 ||
        index == null ||
        index < 0 ||
        index >= ids.length) {
      return (null, null);
    }
    // The list must describe the page being opened, not a foreign list.
    if (ids[index] != zikrId) return (null, null);
    return (ids, index);
  }
}

// router/route_transitions.dart

class RouteTransitions {
  RouteTransitions._();

  /// Slides the page in from the left in RTL (the right in LTR). Swiping
  /// that way (←) drags it back off to return to the previous screen (see
  /// `swipe_back.dart`).
  ///
  /// [swipeBack] makes the whole page take that swipe. Pages whose content
  /// has its own horizontal gestures pass false: the zikr reader's pager
  /// takes the swipe back from its first page itself.
  static CustomTransitionPage<Widget> slideTransition(
    Widget child, {
    required LocalKey key,
    String? restorationId,
    bool swipeBack = true,
  }) {
    return CustomTransitionPage<Widget>(
      key: key,
      restorationId: restorationId,
      child: swipeBack ? SwipeBackDetector(child: child) : child,
      transitionsBuilder: _slideTransition,
    );
  }

  static final Animatable<Offset> _slideIn = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  );
  static final Animatable<Offset> _slideInCurved = _slideIn.chain(
    CurveTween(curve: Curves.easeInOutCubicEmphasized),
  );

  static Widget _slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Linear while a swipe back drags the page, so it stays under the finger.
    final linear = ModalRoute.of(context)!.popGestureInProgress;
    return SlideTransition(
      // Mirrors [_slideIn] in RTL.
      textDirection: Directionality.of(context),
      position: animation.drive(linear ? _slideIn : _slideInCurved),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}
