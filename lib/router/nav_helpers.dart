import 'dart:async';

import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// High-level navigation facade for destinations that don't fit the
/// [ZikrTarget] model. Azkar navigation should prefer typed targets.
class AppNav {
  AppNav._();

  /// Opens a single zikr's detail page (branch-root page).
  static void goToZikr(
    BuildContext context,
    ZikrBranch branch,
    String zikrId, {
    List<String>? zikrIds,
    int? index,
  }) {
    ZikrDetailTarget(
      branch: branch,
      zikrId: zikrId,
      zikrIds: zikrIds,
      index: index,
    ).go(context);
  }

  static void goToDownloadManager(BuildContext context, int tabIndex) {
    unawaited(context.push(AppRoutes.downloadManager(tabIndex)));
  }

  static void goToPdfViewer(BuildContext context, String bookId) {
    // Named route so go_router percent-encodes the id exactly once.
    unawaited(
      context.pushNamed(
        RouteNames.pdfViewer,
        pathParameters: {'bookId': bookId},
      ),
    );
  }
}
