import 'package:flutter/material.dart';

import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/azkar_list_view_widget.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/zikr_list_view_tile_widget.dart';

/// Lists the seven day-wirds of a branch ('أوراد الأسبوع').
class WeekCollectionScreen extends StatelessWidget {
  const WeekCollectionScreen({super.key, required this.branch});

  final ZikrBranch branch;

  static const Map<int, String> daysAzkarTitles = {
    6: 'ورد يوم السبت',
    7: 'ورد يوم الأحد',
    1: 'ورد يوم الإثنين',
    2: 'ورد يوم الثلاثاء',
    3: 'ورد يوم الأربعاء',
    4: 'ورد يوم الخميس',
    5: 'ورد يوم الجمعة',
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
            target: DayWirdTarget(branch, day: day),
          );
        },
      ),
    );
  }
}

/// Lists the individual azkar of one collection.
class ZikrCollectionScreen extends StatelessWidget {
  const ZikrCollectionScreen({
    super.key,
    required this.branch,
    required this.collection,
    required this.azkarTitles,
  });

  final ZikrBranch branch;
  final String collection;
  final List<String> azkarTitles;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(collection),
      ),
      // floatingActionButton: FloatingSliderBtn(titles: azkarTitles),
      body: AzkarListViewWidget(
        titles: azkarTitles,
        barTitle: collection,
        targetBuilder: (title, index) => ZikrDetailTarget(
          branch: branch,
          title: title,
          pagePrefix: RouteNames.zikrCollection(branch),
          collection: collection,
          titles: azkarTitles,
          index: index,
        ),
      ),
    );
  }
}
