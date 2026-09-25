import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/azkar_list_view_widget.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/zikr_list_view_tile_widget.dart';
import 'package:aldurar_alnaqia/widgets/search_widget.dart';
import 'package:aldurar_alnaqia/widgets/swipe_drawer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class AwradListScreen extends ConsumerStatefulWidget {
  const AwradListScreen({super.key});

  @override
  ConsumerState<AwradListScreen> createState() => _AwradListScreenState();
}

class _AwradListScreenState extends ConsumerState<AwradListScreen> {
  /// Displayed collections in registry order, excluding tarajem (shown
  /// as its own tile below, matching the previous layout).
  late final List<String> collectionIds = [
    for (final c in allCollections)
      if (c.id != 'tarajem') c.id,
  ];
  late final List<String> zikrIds = [for (final z in orphanZikrs) z.id];

  @override
  Widget build(BuildContext context) {
    void handleSearch(String query) {
      final id = zikrIdForTitle(query) ?? query;
      final zikr = resolveZikr(id);
      if (zikr == null) return;
      ZikrDetailTarget(branch: ZikrBranch.awrad, zikrId: zikr.id).go(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('أوراد الطريقة'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => SwipeDrawer.of(context).open(),
          tooltip: 'فتح القائمة',
        ),
        actions: [
          SearchWidget(
            onSearch: handleSearch,
            hintText: 'بحث في الأوراد',
            suggestions: allZikrTitles(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            const ZikrListViewTile(
              zikrId: weekCollectionBookmarkId,
              title: 'أوراد الأسبوع',
              target: WeekCollectionTarget(ZikrBranch.awrad),
            ),
            AzkarListViewWidget(
              zikrIds: collectionIds,
              barTitle: 'الأذكار',
              scrollable: false,
              targetBuilder: buildCollectionTarget,
            ),
            AzkarListViewWidget(
              zikrIds: zikrIds,
              barTitle: 'الأذكار',
              scrollable: false,
              targetBuilder: (zikrId, index) => ZikrDetailTarget(
                branch: ZikrBranch.awrad,
                zikrId: zikrId,
                zikrIds: zikrIds,
                index: index,
              ),
            ),
            // Opens the tarajem collection listing; its own tiles then open
            // individual zikr pages under the collection's nested route.
            const AzkarListViewWidget(
              zikrIds: ['tarajem'],
              barTitle: 'الأذكار',
              scrollable: false,
              targetBuilder: buildTarajemTarget,
            ),
          ],
        ),
      ),
    );
  }

  static ZikrCollectionViewTarget buildCollectionTarget(
    String collectionId,
    int index,
  ) =>
      ZikrCollectionViewTarget(ZikrBranch.awrad, collection: collectionId);

  static ZikrCollectionViewTarget buildTarajemTarget(
    String collectionId,
    int index,
  ) =>
      ZikrCollectionViewTarget(ZikrBranch.awrad, collection: collectionId);
}
