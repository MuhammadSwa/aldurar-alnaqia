import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yosria/models/consts/alhadra_collection.dart';
import 'package:yosria/screens/zikr_screen/zikr_screen.dart';
import 'package:yosria/widgets/azkarListView/helia_nasab_screen.dart';
import 'package:yosria/widgets/azkarListView/zikrListViewTile_widget.dart';
import 'package:yosria/widgets/week_azkar_list.dart';
import 'package:yosria/router/page_transitions.dart';
// TODO: reactor this and maybe make the weekazkar, and azkarofdayx it's own iwdget in screens folder?

GoRoute weekCollectionRouter({required String parent}) {
  return GoRoute(
    path: 'weekCollection',
    pageBuilder: (context, state) {
      const daysAzkarTitles = <String, String>{
        '6': 'ورد يوم السبت',
        '7': 'ورد يوم الأحد',
        '1': 'ورد يوم الإثنين',
        '2': 'ورد يوم الثلاثاء',
        '3': 'ورد يوم الأربعاء',
        '4': 'ورد يوم الخميس',
        '5': 'ورد يوم الجمعة',
      };
      return CustomTransitionPage(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('أوراد الأسبوع'),
          ),
          body: ListView(
            children: [
              for (var day in daysAzkarTitles.keys)
                ZikrListViewTile(
                    title: daysAzkarTitles[day]!,
                    route: '/$parent/weekCollection/$day'),
            ],
          ),
        ),
        transitionsBuilder: slideTransition,
      );
    },
    routes: dayCollectionroute(parent: '$parent/weekCollection'),
  );
}

List<GoRoute> dayCollectionroute({required String parent}) {
  return [
    for (var i = 0; i <= 7; i++) ...{
      GoRoute(
        path: i.toString(),
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            child: DayAzkarList(
              dayNum: i,
              route: '/$parent/$i/zikr',
            ),
            transitionsBuilder: slideTransition,
          );
        },
        routes: [azkarDayRoute()],
      ),
    }
  ];
}

GoRoute azkarDayRoute() {
  return GoRoute(
    path: 'zikr/:zikr',
    pageBuilder: (context, state) {
      final zikr = state.pathParameters['zikr']!;
      if (zikr == alhyliaAndNasab.title) {
        return CustomTransitionPage(
          child: const HeliaNasabScreen(),
          transitionsBuilder: slideTransition,
        );
      } else {
        return CustomTransitionPage(
          child: ZikrScreen(title: state.pathParameters['zikr']!),
          transitionsBuilder: slideTransition,
        );
      }
    },
  );
}
