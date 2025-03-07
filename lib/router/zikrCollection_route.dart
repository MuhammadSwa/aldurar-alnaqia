import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yosria/models/azkar_models.dart';
import 'package:yosria/router/page_transitions.dart';
import 'package:yosria/router/zikrPage_router.dart';
import 'package:yosria/widgets/azkarListView/azkarListView_widget.dart';
import 'package:yosria/widgets/zikrSlider_screen.dart';

GoRoute zikrCollectionRoute({required String parent}) {
  return GoRoute(
    path: 'zikrCollection/:collection',
    name: '$parent/zikrCollection/:collection',
    pageBuilder: (context, state) {
      final zikrListTitle = state.pathParameters['collection']!;
      final azkarTitles = azkarCollections.getAzkarTitles(zikrListTitle);
      return CustomTransitionPage(
        child: Scaffold(
          floatingActionButton: FloatingSliderBtn(titles: azkarTitles),
          appBar: AppBar(
            title: Text(zikrListTitle),
          ),
          body: AzkarListViewWidget(
              titles: azkarTitles,
              route: '/$parent/zikrCollection/$zikrListTitle/zikr',
              barTitle: zikrListTitle),
        ),
        transitionsBuilder: slideTransition,
      );
    },
    routes: [
      zikrPageRoute(),
    ],
  );
}
