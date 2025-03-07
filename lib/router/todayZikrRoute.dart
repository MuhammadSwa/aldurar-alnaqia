import 'package:go_router/go_router.dart';
import 'package:yosria/common/helpers/helpers.dart';
import 'package:yosria/widgets/week_azkar_list.dart';
import 'package:yosria/router/page_transitions.dart';
import 'package:yosria/router/week_collection_router.dart';

GoRoute todayZikrRoute() {
  return GoRoute(
    path: 'todaysZikr',
    pageBuilder: (context, state) {
      return CustomTransitionPage(
        child: DayAzkarList(
          dayNum: todaysNum(),
          route: '/home/todaysZikr/zikr',
        ),
        transitionsBuilder: slideTransition,
      );
    },
    routes: [
      azkarDayRoute(),
    ],
  );
}
