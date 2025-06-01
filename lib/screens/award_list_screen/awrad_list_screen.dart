import 'package:aldurar_alnaqia/MyDrawer.dart';
import 'package:aldurar_alnaqia/models/consts/orphans.dart';
import 'package:aldurar_alnaqia/widgets/main_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/zikrListViewTile_widget.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/azkarListView_widget.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:get/get.dart';

// class AwradListScreen extends StatefulWidget {
//   const AwradListScreen({super.key});
//
//   @override
//   State<AwradListScreen> createState() => _AwradListScreenState();
// }

class AwradListScreen extends StatelessWidget {
  const AwradListScreen({super.key});
  static final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    List<String> collectionTitles = azkarCollections.getTitles().sublist(0, 8);
    List<String> azkarTitles = orphanAzkar.getTitles();

    Get.lazyPut(() => GlobalDrawerController());
    final drawerController = Get.find<GlobalDrawerController>();

    drawerController.registerScaffoldKey(_scaffoldKey);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('اوراد الطريقة'),
        leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: 'فتح القائمة'),
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
            // TODO: A HACK asrGomma should be on top of taragm, util i rethink of better implementation
            AzkarListViewWidget(
              titles: [asrGomaa.title],
              route: '/awradScreen/zikr',
              barTitle: 'الأذكار',
              scrollable: false,
            ),
            const AzkarListViewWidget(
              // titles: [...tareeqaBiosCollection.map((e) => e.title)],
              titles: ['تراجم رجال الطريقة'],
              route: '/awradScreen/zikrCollection',
              barTitle: 'الأذكار',
              scrollable: false,
            ),
            //

            AzkarListViewWidget(
              titles: azkarTitles,
              route: '/awradScreen/zikr',
              barTitle: 'الأذكار',
              scrollable: false,
            ),
          ],
        ),
      ),
    );
  }
}
