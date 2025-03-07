import 'package:flutter/material.dart';
import 'package:yosria/widgets/azkarListView/zikrListViewTile_widget.dart';
import 'package:yosria/screens/award_list_screen/search_bar_widget.dart';
import 'package:yosria/widgets/azkarListView/azkarListView_widget.dart';
import 'package:yosria/models/azkar_models.dart';

class AwradListScreen extends StatefulWidget {
  const AwradListScreen({super.key});

  @override
  State<AwradListScreen> createState() => _AwradListScreenState();
}

class _AwradListScreenState extends State<AwradListScreen> {
  @override
  Widget build(BuildContext context) {
    List<String> collectionTitles = azkarCollections.getTitles();
    List<String> azkarTitles = orphanAzkar.getTitles();

    return Scaffold(
      appBar: const SearchBarWidget(),
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
