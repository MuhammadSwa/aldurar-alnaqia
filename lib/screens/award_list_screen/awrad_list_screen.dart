import 'package:aldurar_alnaqia/my_drawer.dart';
import 'package:aldurar_alnaqia/models/consts/orphans.dart';
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
      context.goNamed(
        'awradZikrPage',
        pathParameters: {'zikr': Uri.encodeComponent(query)},
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
                title: 'أوراد الأسبوع', route: '/awradScreen/weekCollection'),
            AzkarListViewWidget(
              titles: collectionTitles,
              route: '/awradScreen/zikrCollection',
              barTitle: 'الأذكار',
              scrollable: false,
            ),
            // TODO: hack asrGomma should be on top of taragm, util i rethink of better implementation
            AzkarListViewWidget(
              titles: [asrGomaa.title],
              route: '/awradScreen/zikr',
              barTitle: 'الأذكار',
              scrollable: false,
            ),

            AzkarListViewWidget(
              titles: azkarTitles,
              route: '/awradScreen/zikr',
              barTitle: 'الأذكار',
              scrollable: false,
            ),

            // TODO: hack
            // AzkarListViewWidget appends the title, producing
            // '/awradScreen/zikrCollection/تراجم رجال الطريقة'.
            const AzkarListViewWidget(
              titles: ['تراجم رجال الطريقة'],
              route: '/awradScreen/zikrCollection',
              barTitle: 'الأذكار',
              scrollable: false,
            ),
          ],
        ),
      ),
    );
  }
}
