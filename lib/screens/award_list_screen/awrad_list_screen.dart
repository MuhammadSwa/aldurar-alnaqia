import 'package:aldurar_alnaqia/my_drawer.dart';
import 'package:aldurar_alnaqia/models/consts/orphans.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/widgets/search_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/zikr_list_view_tile_widget.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/azkar_list_view_widget.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:go_router/go_router.dart';

class AwradListScreen extends ConsumerStatefulWidget {
  const AwradListScreen({super.key});

  @override
  ConsumerState<AwradListScreen> createState() => _AwradListScreenState();
}

class _AwradListScreenState extends ConsumerState<AwradListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<String> collectionTitles =
      azkarCollections.getTitles().sublist(0, 8);
  late final List<String> azkarTitles = orphanAzkar.getTitles();

  @override
  Widget build(BuildContext context) {
    ref.watch(drawerRegistryProvider).registerScaffoldKey(_scaffoldKey);

    void handleSearch(String query) {
      // Pass the raw title; go_router percent-encodes path parameters itself.
      context.goNamed(
        RouteNames.zikrPage(ZikrBranch.awrad.namePrefix),
        pathParameters: {'zikr': query},
      );
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
            suggestions: allAzkar.getTitles(),
          ),
        ],
      ),
      drawer: const MyDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const ZikrListViewTile(
                title: 'أوراد الأسبوع',
                target: WeekCollectionTarget(ZikrBranch.awrad)),
            AzkarListViewWidget(
              titles: collectionTitles,
              barTitle: 'الأذكار',
              scrollable: false,
              targetBuilder: buildCollectionTarget,
            ),
            // TODO: hack asrGomma should be on top of taragm, util i rethink of better implementation
            AzkarListViewWidget(
              titles: [asrGomaa.title],
              barTitle: 'الأذكار',
              scrollable: false,
              targetBuilder: buildAsrGomaaTarget,
            ),

            AzkarListViewWidget(
              titles: azkarTitles,
              barTitle: 'الأذكار',
              scrollable: false,
              targetBuilder: (title, index) => ZikrDetailTarget(
                branch: ZikrBranch.awrad,
                title: title,
                titles: azkarTitles,
                index: index,
              ),
            ),

            // TODO: hack
            // Opens the tarajem collection listing; its own tiles then open
            // individual zikr pages under the collection's nested route.
            const AzkarListViewWidget(
              titles: ['تراجم رجال الطريقة'],
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
          String title, int index) =>
      ZikrCollectionViewTarget(ZikrBranch.awrad, collection: title);

  static ZikrCollectionViewTarget buildTarajemTarget(
          String title, int index) =>
      ZikrCollectionViewTarget(ZikrBranch.awrad, collection: title);

  static ZikrDetailTarget buildAsrGomaaTarget(String title, int index) {
    return ZikrDetailTarget(branch: ZikrBranch.awrad, title: title);
  }
}
