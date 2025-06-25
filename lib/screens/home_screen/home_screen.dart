import 'package:aldurar_alnaqia/MyDrawer.dart';
import 'package:aldurar_alnaqia/models/consts/dalayil_alkhayrat_collection.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';
import 'package:aldurar_alnaqia/widgets/main_wrapper.dart';
import 'package:aldurar_alnaqia/widgets/search_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aldurar_alnaqia/common/helpers/helpers.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/bookmarks_controller.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/zikrListViewTile_widget.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/azkarListView_widget.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  static final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    void handleSearch(String query) {
      context.go('/home/zikr/$query');
    }

    Get.lazyPut(() => GlobalDrawerController());
    final drawerController = Get.find<GlobalDrawerController>();

    drawerController.registerScaffoldKey(_scaffoldKey);

    final controller = Get.put(PrayerTimingsController());

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('الدرر النقية'),
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                textDirection: TextDirection
                    .rtl, // Ensures icon is on the right for Arabic
                children: [
                  Icon(Icons.today_rounded),
                  SizedBox(width: 8),
                  Text(
                    'أوراد اليوم',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    // style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    //       fontWeight: FontWeight.bold,
                    //     ),
                  ),
                ],
              ),
            ),
            Obx(() {
              // TODO: make it truely reactive(change after maghrib)
              final dayNum = controller.islamicWeekday.value;
              final dayIndex = dayNum - 1;

              return Column(
                children: [
                  ListTile(
                    title: Text(
                      'ورد يوم ${arabicWeekdays[dayIndex]}',
                    ),
                    leading: const Icon(Icons.arrow_right),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.go('/home/todaysZikr');
                    },
                  ),
                  ListTile(
                    title: Text(
                      'دلائل الخيرات ورد يوم ${arabicWeekdays[dayIndex]}',
                    ),
                    leading: const Icon(Icons.arrow_right),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.go(
                          '/home/zikr/${dalayilAlkhayratCollection[dayIndex].title}');
                    },
                  ),
                ],
              );
            }),

            // ZikrOfTheDayTile(
            //     title: 'ورد يوم ${arabicWeekdays[todaysNum() - 1]}',
            //     route: '/home/todaysZikr'),
            const Divider(),
            const BookmarksTilesHomeScreen(),
            //
            // if (Platform.isAndroid) const NotificationSettings()
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
        return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
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
                    scrollable: false,
                  ),
                  AzkarListViewWidget(
                    titles: orphanTitles,
                    route: '/home/zikr',
                    barTitle: 'الأذكار',
                    scrollable: false,
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
            ));
      },
    );
  }
}
