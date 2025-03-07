import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yosria/common/helpers/helpers.dart';
import 'package:yosria/screens/home_screen/home_popup_menu.dart';
import 'package:yosria/widgets/azkarListView/bookmarks_controller.dart';
import 'package:yosria/widgets/azkarListView/zikrListViewTile_widget.dart';
import 'package:yosria/widgets/azkarListView/zikrOfTheDayTile_widget.dart';
import 'package:yosria/models/azkar_models.dart';
import 'package:yosria/widgets/azkarListView/azkarListView_widget.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطريقة اليسرية'),
        actions: const [
          HomePopUpMenu(),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ZikrOfTheDayTile(
                title: 'ورد يوم ${arabicWeekdays[todaysNum() - 1]}',
                route: '/home/todaysZikr'),
            const Divider(),

            const BookmarksTilesHomeScreen(),
            //
          ],
        ),
      ),
    );
  }
}

class BookmarksTilesHomeScreen extends StatelessWidget {
  const BookmarksTilesHomeScreen({super.key});

  static const azkarDayTitlesToNum = <String, String>{
    'ورد يوم الإثنين': '1',
    'ورد يوم الثلاثاء': '2',
    'ورد يوم الأربعاء': '3',
    'ورد يوم الخميس': '4',
    'ورد يوم الجمعة': '5',
    'ورد يوم السبت': '6',
    'ورد يوم الأحد': '7',
  };

  @override
  Widget build(BuildContext context) {
    // TODO: refactor this
    return GetBuilder<BookmarksController>(
      init: BookmarksController(),
      builder: (c) {
        final bookmarks = c.bookmarks;

        // TODO: refactor this
        // see if a bookmark is collection or orphan
        final List<String> collectionTitles = [];
        final List<String> orphanTitles = [];
        final List<String> azkarOfDays = [];
        var weekAzkarBookmarked = false;

        for (var bookmark in bookmarks) {
          if (azkarDayTitlesToNum.keys.contains(bookmark)) {
            azkarOfDays.add(bookmark);
          } else if (bookmark == 'أوراد الأسبوع') {
            weekAzkarBookmarked = true;
          } else if (azkarCollections.azkarCategList.keys.contains(bookmark)) {
            collectionTitles.add(bookmark);
          } else {
            orphanTitles.add(bookmark);
          }
        }
        return Column(
          children: [
            if (weekAzkarBookmarked) ...{
              const ZikrListViewTile(
                  title: 'أوراد الأسبوع', route: '/home/weekCollection'),
            },
            if (bookmarks.isNotEmpty) ...{
              for (var day in azkarOfDays) ...{
                ZikrListViewTile(
                    title: day, route: '/home/${azkarDayTitlesToNum[day]}'),
              },
              AzkarListViewWidget(
                titles: collectionTitles,
                route: '/home/zikrCollection',
                barTitle: 'الأذكار',
              ),
              AzkarListViewWidget(
                titles: orphanTitles,
                route: '/home/zikr',
                barTitle: 'الأذكار',
              ),
            } else ...{
              // TODO: design empty state
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('المحفوظات فارغة'),
                  Icon(Icons.bookmark_remove)
                ],
              ),
            }
          ],
        );
      },
    );
  }
}
