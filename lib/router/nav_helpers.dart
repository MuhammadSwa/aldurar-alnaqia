import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:aldurar_alnaqia/router/app_routes.dart';

/// High-level navigation facade for destinations that don't fit the
/// [ZikrTarget] model. Azkar navigation should prefer typed targets.
class AppNav {
  AppNav._();

  /// Opens a single zikr's detail page (branch-root page).
  static void goToZikr(
    BuildContext context,
    ZikrBranch branch,
    String title, {
    List<String>? titles,
    int? index,
  }) {
    ZikrDetailTarget(
      branch: branch,
      title: title,
      titles: titles,
      index: index,
    ).go(context);
  }

  static void goToDownloadManager(BuildContext context, int tabIndex) {
    context.push(AppRoutes.downloadManager(tabIndex));
  }

  static void goToPdfViewer(BuildContext context, String bookTitle) {
    // Named route so go_router percent-encodes the Arabic title exactly once.
    context.pushNamed(
      RouteNames.pdfViewer,
      pathParameters: {'bookTitle': bookTitle},
    );
  }
}
