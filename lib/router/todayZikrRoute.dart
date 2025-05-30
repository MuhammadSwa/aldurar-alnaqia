import 'package:go_router/go_router.dart';
import 'package:aldurar_alnaqia/common/helpers/helpers.dart';
import 'package:aldurar_alnaqia/widgets/week_azkar_list.dart';
import 'package:aldurar_alnaqia/router/page_transitions.dart';
import 'package:aldurar_alnaqia/router/week_collection_router.dart';

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
