import 'package:aldurar_alnaqia/MyDrawer.dart';
import 'package:aldurar_alnaqia/models/consts/dalayil_alkhayrat_collection.dart';
import 'package:aldurar_alnaqia/widgets/main_wrapper.dart';
import 'package:aldurar_alnaqia/widgets/search_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aldurar_alnaqia/common/helpers/helpers.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/bookmarks_controller.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/zikrListViewTile_widget.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/zikrOfTheDayTile_widget.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/azkarListView_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:adhan_dart/adhan_dart.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  static final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    print(DateTime.now().timeZoneOffset);

    void handleSearch(String query) {
      context.go('/home/zikr/$query');
    }

    // Coordinates coordinates = Coordinates(31.30, 30.63);
    // // Coordinates coordinates = Coordinates(30.63, 31.30);
    // CalculationParameters params = CalculationMethod.egyptian();
    // params.madhab = Madhab.shafi;
    // PrayerTimes prayerTimes = PrayerTimes(
    //     coordinates: coordinates,
    //     date: DateTime.now(),
    //     calculationParameters: params,
    //     precision: true);
    //
    // DateTime fajrTime = prayerTimes.fajr!;
    // DateTime sunriseTime = prayerTimes.sunrise!;
    // DateTime dhuhrTime = prayerTimes.dhuhr!;
    // DateTime asrTime = prayerTimes.asr!;
    // DateTime maghribTime = prayerTimes.maghrib!;
    // DateTime ishaTime = prayerTimes.isha!;
    // print("Fajr: $fajrTime");
    // print("Sunrise: $sunriseTime");
    // print("Dhuhr: $dhuhrTime");
    // print("Asr: $asrTime");
    // print("Maghrib: $maghribTime");
    // print("Isha: $ishaTime");

    Get.lazyPut(() => GlobalDrawerController());
    final drawerController = Get.find<GlobalDrawerController>();

    drawerController.registerScaffoldKey(_scaffoldKey);

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
            ZikrOfTheDayTile(
                title: 'ورد يوم ${arabicWeekdays[todaysNum() - 1]}',
                route: '/home/todaysZikr'),

            ZikrOfTheDayTile(
                title:
                    'دلائل الخيرات ورد يوم ${arabicWeekdays[todaysNum() - 1]}',
                route:
                    '/home/zikr/${dalayilAlkhayratCollection[todaysNum() - 1].title}'),
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
