import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// Routing contract — the single source of truth for everything navigation
// related in the app.
//
// Rules of the road:
//  * Widgets NEVER build location strings themselves. Either use one of the
//    typed [ZikrTarget]s / [AppRoutes] builders, or navigate by route NAME
//    via `goNamed`/`pushNamed`.
//  * Path parameters (Arabic titles, collection names, ...) are always passed
//    RAW to go_router; it encodes them when building the location and decodes
//    them in `state.pathParameters`. Never call Uri.encode/decodeComponent
//    manually — doing both sides causes double-encoding bugs.
//  * Non-ASCII segments must only travel through named routes or the
//    builders below, never hand-concatenated strings.
// ---------------------------------------------------------------------------

/// Absolute route paths for top-level destinations.
class RoutePaths {
  static const String home = '/home';
  static const String timings = '/timings';
  static const String awrad = '/awradScreen';
  static const String library = '/library';
  static const String settings = '/settings';
  static const String social = '/social';
  static const String downloadManager = '/downloadManager';

  // Nested segments (relative, used only inside app_router.dart).
  static const String todaysZikrSegment = 'todaysZikr';
  static const String weekCollectionSegment = 'weekCollection';
  static const String zikrCollectionSegment = 'zikrCollection/:collection';
  static const String zikrSegment = 'zikr/:zikr';
}

/// Named-route registry. Zikr detail pages exist once per parent route, so
/// their names are generated from the parent prefix (e.g. `zikrPage('home')`
/// -> `homeZikrPage`).
class RouteNames {
  static const String home = 'home';
  static const String timings = 'timings';
  static const String awrad = 'awrad';
  static const String library = 'library';
  static const String todayZikr = 'todayZikr';
  static const String heliaNasab = 'heliaNasab';
  static const String pdfViewer = 'pdfViewer';

  /// Name of a branch's week-collection listing (`homeWeekCollection`).
  static String weekCollection(ZikrBranch branch) =>
      '${branch.namePrefix}WeekCollection';

  /// Name of a branch's zikr-collection listing (`homeZikrCollection`).
  static String zikrCollection(ZikrBranch branch) =>
      '${branch.namePrefix}ZikrCollection';

  /// Name of a branch's day-wird page (`homeWeekCollection3`).
  static String weekCollectionDay(ZikrBranch branch, int day) =>
      '${branch.namePrefix}WeekCollection$day';

  /// Name of the nested zikr detail page under [prefix].
  static String zikrPage(String prefix) => '${prefix}ZikrPage';

  /// Prefix for today's-zikr nested pages.
  static String get todayZikrPagePrefix => todayZikr;
}

/// The two branches that host azkar content.
enum ZikrBranch {
  home,
  awrad;

  /// First path segment of the branch root (`/home`, `/awradScreen`).
  String get pathSegment => switch (this) {
        ZikrBranch.home => 'home',
        ZikrBranch.awrad => 'awradScreen',
      };

  /// Prefix used for route names registered under this branch.
  String get namePrefix => switch (this) {
        ZikrBranch.home => 'home',
        ZikrBranch.awrad => 'awrad',
      };
}

/// Typed extras contract for zikr detail pages.
class ZikrRouteExtra {
  final List<String>? titles;
  final int? index;
  const ZikrRouteExtra({this.titles, this.index});
}

/// Centralized location builders. Only ASCII-safe segments may be
/// interpolated here; anything user-facing/Arabic goes through named routes.
class AppRoutes {
  AppRoutes._();

  static String weekCollectionPath(ZikrBranch branch) =>
      '/${branch.pathSegment}/weekCollection';

  static String dayWirdPath(ZikrBranch branch, int day) =>
      '${weekCollectionPath(branch)}/$day';

  static String todaysZikrPath() => '${RoutePaths.home}/todaysZikr';

  static String downloadManager(int tabIndex) =>
      '${RoutePaths.downloadManager}/$tabIndex';

  static String pdfViewerPath(String bookTitle) =>
      '${RoutePaths.library}/pdfViewer/$bookTitle';
}

// ---------------------------------------------------------------------------
// Typed navigation targets
// ---------------------------------------------------------------------------

/// Base class of every azkar-related destination. Screens and tiles hold
/// these instead of raw path strings, keeping navigation type-safe and
/// encoding-correct by construction.
sealed class ZikrTarget {
  const ZikrTarget();

  void go(BuildContext context);
}

/// Opens a single zikr's detail page under [branch]'s nested
/// `zikr/:zikr` route identified by [pagePrefix]. When [titles] and [index]
/// are provided the page becomes swipeable across [titles].
class ZikrDetailTarget extends ZikrTarget {
  const ZikrDetailTarget({
    required this.branch,
    required this.title,
    this.pagePrefix,
    this.collection,
    this.titles,
    this.index,
  });

  final ZikrBranch branch;
  final String title;

  /// Route-name prefix of the exact nested zikr page to open. Defaults to
  /// the branch root page (e.g. `homeZikrPage`).
  final String? pagePrefix;

  /// Collection name when opening from inside a collection listing; the
  /// collection-nested zikr route requires its `:collection` parameter.
  final String? collection;

  final List<String>? titles;
  final int? index;

  @override
  void go(BuildContext context) {
    context.goNamed(
      RouteNames.zikrPage(pagePrefix ?? branch.namePrefix),
      pathParameters: collection == null
          ? {'zikr': title}
          : {'collection': collection!, 'zikr': title},
      extra: ZikrRouteExtra(titles: titles, index: index),
    );
  }
}

/// Opens today's wird listing (`/<branch>/todaysZikr`, home branch only).
class TodaysZikrTarget extends ZikrTarget {
  const TodaysZikrTarget();

  @override
  void go(BuildContext context) => context.go(AppRoutes.todaysZikrPath());
}

/// Opens the week-collection listing of [branch].
class WeekCollectionTarget extends ZikrTarget {
  const WeekCollectionTarget(this.branch);

  final ZikrBranch branch;

  @override
  void go(BuildContext context) =>
      context.go(AppRoutes.weekCollectionPath(branch));
}

/// Opens a single day's wird page of [branch].
class DayWirdTarget extends ZikrTarget {
  const DayWirdTarget(this.branch, {required this.day});

  final ZikrBranch branch;
  final int day;

  @override
  void go(BuildContext context) =>
      context.go(AppRoutes.dayWirdPath(branch, day));
}

/// Opens a zikr collection listing (e.g. 'الحضرة الصديقية') of [branch].
class ZikrCollectionViewTarget extends ZikrTarget {
  const ZikrCollectionViewTarget(this.branch, {required this.collection});

  final ZikrBranch branch;
  final String collection;

  @override
  void go(BuildContext context) {
    context.goNamed(
      RouteNames.zikrCollection(branch),
      pathParameters: {'collection': collection},
    );
  }
}
