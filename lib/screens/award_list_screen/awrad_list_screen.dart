import 'package:aldurar_alnaqia/my_drawer.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/widgets/search_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/zikr_list_view_tile_widget.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/azkar_list_view_widget.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';

class AwradListScreen extends ConsumerStatefulWidget {
  const AwradListScreen({super.key});

  @override
  ConsumerState<AwradListScreen> createState() => _AwradListScreenState();
}

class _AwradListScreenState extends ConsumerState<AwradListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Displayed collections in registry order, excluding tarajem (shown
  /// as its own tile below, matching the previous layout).
  late final List<String> collectionIds = [
    for (final c in allCollections)
      if (c.id != 'tarajem') c.id,
  ];
  late final List<String> zikrIds = [for (final z in orphanZikrs) z.id];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(drawerRegistryProvider).registerScaffoldKey(_scaffoldKey);
    });
  }

  @override
  void dispose() {
    try {
      ref.read(drawerRegistryProvider).unregisterScaffoldKey(_scaffoldKey);
    } catch (_) {
      // Registry already disposed; ignore.
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void handleSearch(String query) {
      final zikr = resolveZikr(query);
      if (zikr == null) return;
      ZikrDetailTarget(branch: ZikrBranch.awrad, zikrId: zikr.id).go(context);
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('أوراد الطريقة'),
        leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: 'فتح القائمة'),
        actions: [
          SearchWidget(
            onSearch: handleSearch,
            hintText: 'بحث في الأوراد',
            suggestions: allZikrTitles(),
          ),
        ],
      ),
      drawer: const MyDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const ZikrListViewTile(
                zikrId: weekCollectionBookmarkId,
                title: 'أوراد الأسبوع',
                target: WeekCollectionTarget(ZikrBranch.awrad)),
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
          String collectionId, int index) =>
      ZikrCollectionViewTarget(ZikrBranch.awrad, collection: collectionId);

  static ZikrCollectionViewTarget buildTarajemTarget(
          String collectionId, int index) =>
      ZikrCollectionViewTarget(ZikrBranch.awrad, collection: collectionId);
}
