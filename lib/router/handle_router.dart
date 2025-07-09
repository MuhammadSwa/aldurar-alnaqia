// router/app_router.dart
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:aldurar_alnaqia/widgets/main_wrapper.dart';
import 'package:aldurar_alnaqia/screens/home_screen/home_screen.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_screen.dart';
import 'package:aldurar_alnaqia/screens/award_list_screen/awrad_list_screen.dart';
import 'package:aldurar_alnaqia/screens/library_screen/library_screen.dart';
import 'package:aldurar_alnaqia/screens/library_screen/pdf_viewer_widget.dart';
import 'package:aldurar_alnaqia/screens/social_screen/social_screen.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_manager_screen.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/zikr_screen.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/helia_nasab_screen.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/azkarListView_widget.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/zikrListViewTile_widget.dart';
import 'package:aldurar_alnaqia/widgets/week_azkar_list.dart';
import 'package:aldurar_alnaqia/common/helpers/helpers.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/models/consts/alhadra_collection.dart';
import 'package:aldurar_alnaqia/models/consts/orphans.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRouter {
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: RoutePaths.home,
      debugLogDiagnostics: true,
      navigatorKey: _rootNavigatorKey,
      routes: [
        // Standalone routes (not in bottom nav)
        _createSocialRoute(),
        _createDownloadManagerRoute(),
        // _createSliderRoute(),

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

  // Standalone routes

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
        return DownloadManagerPage(
          initialIndex: index,
        );
      },
    );
  }

  // static GoRoute _createSliderRoute() {
  //   return GoRoute(
  //     path: RoutePaths.slider,
  //     builder: (context, state) {
  //       final titles = state.extra as List<String>;
  //       return ZikrsliderScreen(titles);
  //     },
  //   );
  // }

  // Bottom navigation branches
  static StatefulShellBranch _createHomeBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: RoutePaths.home,
          name: RouteNames.home,
          builder: (context, state) => HomePage(),
          routes: [
            _createTodayZikrRoute(),
            _createWeekCollectionRoute('home'),
            _createZikrCollectionRoute('home'),
            _createZikrPageRoute('home'),
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
          builder: (context, state) => AwradListScreen(),
          routes: [
            _createWeekCollectionRoute('awrad'),
            _createZikrCollectionRoute('awrad'),
            _createZikrPageRoute('awrad'),
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

  // Nested routes
  static GoRoute _createTodayZikrRoute() {
    final controller = Get.put(PrayerTimingsController());
    return GoRoute(
      path: 'todaysZikr',
      name: RouteNames.todayZikr,
      pageBuilder: (context, state) {
        return RouteTransitions.slideTransition(
          DayAzkarList(
            dayNum: controller.islamicWeekday.value,
            route: '${_getCurrentPath(state)}/zikr',
          ),
        );
      },
      routes: [_createZikrPageRoute('todayZikr')],
    );
  }

  static GoRoute _createWeekCollectionRoute(String branch) {
    return GoRoute(
      path: 'weekCollection',
      name: '${branch}WeekCollection',
      pageBuilder: (context, state) {
        return RouteTransitions.slideTransition(
          WeekCollectionScreen(basePath: _getCurrentPath(state)),
        );
      },
      routes: _createDayCollectionRoutes(branch),
    );
  }

  static List<GoRoute> _createDayCollectionRoutes(String branch) {
    return List.generate(8, (index) {
      return GoRoute(
        path: index.toString(),
        pageBuilder: (context, state) {
          return RouteTransitions.slideTransition(
            DayAzkarList(
              dayNum: index,
              route: '${_getCurrentPath(state)}/zikr',
            ),
          );
        },
        routes: [_createZikrPageRoute('${branch}WeekCollection$index')],
      );
    });
  }

  static GoRoute _createZikrCollectionRoute(String branch) {
    return GoRoute(
      path: 'zikrCollection/:collection',
      name: '${branch}ZikrCollection',
      pageBuilder: (context, state) {
        final collection = state.pathParameters['collection']!;
        final azkarTitles = azkarCollections.getAzkarTitles(collection);

        return RouteTransitions.slideTransition(
          ZikrCollectionScreen(
            collection: collection,
            azkarTitles: azkarTitles,
            basePath: _getCurrentPath(state),
          ),
        );
      },
      routes: [_createZikrPageRoute('${branch}ZikrCollection')],
    );
  }

// TODO: get extra titles here
  static GoRoute _createZikrPageRoute(String prefix) {
    return GoRoute(
      path: 'zikr/:zikr',
      name: '${prefix}ZikrPage',
      pageBuilder: (context, state) {
        final zikr = state.pathParameters['zikr']!;

        List<String>? titles;
        int? index;
// extra: {titles, index;
        if (state.extra != null && state.extra is Map<String, dynamic>) {
          final Map<String, dynamic> extra =
              state.extra as Map<String, dynamic>;

          titles = extra['titles'] as List<String>;

          index = extra['index'] as int;
        }

        // Handle special cases
        if (zikr == alhyliaAndNasab.title) {
          return RouteTransitions.slideTransition(const HeliaNasabScreen());
        }
        if (zikr == sanadAltareeqa.title) {
          return RouteTransitions.slideTransition(const TareeqaSanadScreen());
        }

        return RouteTransitions.slideTransition(
            ZikrScreen(title: zikr, titles: titles, index: index));
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

  // Helper method to get current path
  static String _getCurrentPath(GoRouterState state) {
    return state.matchedLocation;
  }
}

// router/route_paths.dart
class RoutePaths {
  static const String home = '/home';
  static const String timings = '/timings';
  static const String awrad = '/awradScreen';
  static const String library = '/library';
  static const String settings = '/settings';
  static const String social = '/social';
  static const String downloadManager = '/downloadManager';
  static const String slider = '/slider';
}

class RouteNames {
  static const String home = 'home';
  static const String timings = 'timings';
  static const String awrad = 'awrad';
  static const String library = 'library';
  static const String todayZikr = 'todayZikr';
  static const String heliaNasab = 'heliaNasab';
  static const String pdfViewer = 'pdfViewer';
}

// router/route_transitions.dart

class RouteTransitions {
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

// widgets/week_collection_screen.dart

class WeekCollectionScreen extends StatelessWidget {
  final String basePath;

  const WeekCollectionScreen({
    super.key,
    required this.basePath,
  });

  static const Map<String, String> daysAzkarTitles = {
    '6': 'ورد يوم السبت',
    '7': 'ورد يوم الأحد',
    '1': 'ورد يوم الإثنين',
    '2': 'ورد يوم الثلاثاء',
    '3': 'ورد يوم الأربعاء',
    '4': 'ورد يوم الخميس',
    '5': 'ورد يوم الجمعة',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أوراد الأسبوع'),
      ),
      body: ListView.builder(
        itemCount: daysAzkarTitles.length,
        itemBuilder: (context, index) {
          final day = daysAzkarTitles.keys.elementAt(index);
          final title = daysAzkarTitles[day]!;

          return ZikrListViewTile(
            title: title,
            route: '$basePath/$day',
          );
        },
      ),
    );
  }
}

// widgets/zikr_collection_screen.dart

class ZikrCollectionScreen extends StatelessWidget {
  final String collection;
  final List<String> azkarTitles;
  final String basePath;

  const ZikrCollectionScreen({
    super.key,
    required this.collection,
    required this.azkarTitles,
    required this.basePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(collection),
      ),
      // floatingActionButton: FloatingSliderBtn(titles: azkarTitles),
      body: AzkarListViewWidget(
        titles: azkarTitles,
        route: '$basePath/zikr',
        barTitle: collection,
      ),
    );
  }
}
