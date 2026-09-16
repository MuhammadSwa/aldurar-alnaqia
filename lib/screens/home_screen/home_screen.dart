import 'package:aldurar_alnaqia/models/consts/dalayil_alkhayrat_collection.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/widgets/search_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/common/helpers/helpers.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/zikr_list_view_tile_widget.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/azkar_list_view_widget.dart';
import 'package:aldurar_alnaqia/router/nav_helpers.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart'
    show prayerProvider;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  void handleSearch(String query) {
    // Search suggestions are display titles; resolve to the stable id.
    final zikr = resolveZikr(query);
    if (zikr == null) return;
    ZikrDetailTarget(branch: ZikrBranch.home, zikrId: zikr.id).go(context);
  }

  @override
  Widget build(BuildContext context) {
    final islamicWeekday =
        ref.watch(prayerProvider.select((state) => state.islamicWeekday));
    final dayIndex = islamicWeekday - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدرر النقية'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () =>
              ref.read(rootScaffoldKeyProvider).currentState?.openDrawer(),
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
                  ),
                ],
              ),
            ),
            Column(
              children: [
                ListTile(
                  title: Text(
                    'ورد يوم ${arabicWeekdays[dayIndex]}',
                  ),
                  leading: const Icon(Icons.arrow_right),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => const TodaysZikrTarget().go(context),
                ),
                ListTile(
                  title: Text(
                    'دلائل الخيرات ورد يوم ${arabicWeekdays[dayIndex]}',
                  ),
                  leading: const Icon(Icons.arrow_right),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    AppNav.goToZikr(
                      context,
                      ZikrBranch.home,
                      dalayilAlkhayratCollection[dayIndex].id,
                    );
                  },
                ),
              ],
            ),
            const Divider(),
            const BookmarksTilesHomeScreen(),
          ],
        ),
      ),
    );
  }
}

class BookmarksTilesHomeScreen extends ConsumerWidget {
  const BookmarksTilesHomeScreen({super.key});

  static int? _dayFromBookmark(String bookmark) {
    if (!bookmark.startsWith('day-wird-')) return null;
    final day = int.tryParse(bookmark.split('-').last);
    if (day != null && dayWirdTitles.containsKey(day)) return day;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);

    // see if a bookmark is collection or orphan
    final List<String> collectionIds = [];
    final List<String> orphanIds = [];
    final List<int> azkarOfDays = [];
    var weekAzkarBookmarked = false;

    for (var bookmark in bookmarks) {
      final day = _dayFromBookmark(bookmark);
      if (day != null) {
        azkarOfDays.add(day);
      } else if (bookmark == weekCollectionBookmarkId) {
        weekAzkarBookmarked = true;
      } else if (collectionById.containsKey(bookmark)) {
        collectionIds.add(bookmark);
      } else {
        orphanIds.add(bookmark);
      }
    }

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          if (weekAzkarBookmarked) ...{
            const ZikrListViewTile(
              zikrId: weekCollectionBookmarkId,
              title: 'أوراد الأسبوع',
              target: WeekCollectionTarget(ZikrBranch.home),
            ),
          },
          if (bookmarks.isNotEmpty) ...{
            for (var day in azkarOfDays) ...{
              ZikrListViewTile(
                zikrId: dayWirdBookmarkId(day),
                title: dayWirdTitles[day],
                target: DayWirdTarget(ZikrBranch.home, day: day),
              ),
            },
            AzkarListViewWidget(
              zikrIds: collectionIds,
              barTitle: 'الأذكار',
              scrollable: false,
              targetBuilder: (collectionId, index) => ZikrCollectionViewTarget(
                ZikrBranch.home,
                collection: collectionId,
              ),
            ),
            AzkarListViewWidget(
              zikrIds: orphanIds,
              barTitle: 'الأذكار',
              scrollable: false,
              targetBuilder: (zikrId, index) => ZikrDetailTarget(
                branch: ZikrBranch.home,
                zikrId: zikrId,
                zikrIds: orphanIds,
                index: index,
              ),
            ),
          } else ...{
            // TODO: design empty state
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [Text('المحفوظات فارغة'), Icon(Icons.bookmark_remove)],
            ),
          },
        ],
      ),
    );
  }
}
