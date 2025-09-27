import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:aldurar_alnaqia/router/handle_router.dart';

class AppNav {
  static void goToZikr(BuildContext context, String baseName, String zikr,
      {List<String>? titles, int? index}) {
    context.goNamed(
      '${baseName}ZikrPage',
      pathParameters: {'zikr': zikr},
      extra: ZikrRouteExtra(titles: titles, index: index),
    );
  }

  static void goToDownloadManager(BuildContext context, int tabIndex) {
    context.push('${RoutePaths.downloadManager}/$tabIndex');
  }
}
