import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/azkar_list_view_widget.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/zikr_list_view_tile_widget.dart';
import 'package:material_ui/material_ui.dart';

/// Lists the seven day-wirds of a branch ('أوراد الأسبوع').
class WeekCollectionScreen extends StatelessWidget {
  const WeekCollectionScreen({required this.branch, super.key});

  final ZikrBranch branch;

  @override
  Widget build(BuildContext context) {
    final days = dayWirdTitles.keys.toList()..sort();
    return Scaffold(
      appBar: AppBar(
        title: const Text('أوراد الأسبوع'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];

          return ZikrListViewTile(
            zikrId: dayWirdBookmarkId(day),
            title: dayWirdTitles[day],
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
    required this.branch, required this.collection, required this.collectionId, required this.zikrIds, super.key,
  });

  final ZikrBranch branch;
  final String collection;
  final String collectionId;
  final List<String> zikrIds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(collection),
      ),
      body: AzkarListViewWidget(
        zikrIds: zikrIds,
        barTitle: collection,
        targetBuilder: (zikrId, index) => ZikrDetailTarget(
          branch: branch,
          zikrId: zikrId,
          pagePrefix: RouteNames.zikrCollection(branch),
          collection: collectionId,
          zikrIds: zikrIds,
          index: index,
        ),
      ),
    );
  }
}
