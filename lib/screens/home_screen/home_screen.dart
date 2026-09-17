import 'package:aldurar_alnaqia/common/widgets/app_tile.dart';
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
import 'package:aldurar_alnaqia/prayer/prayer_providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  void handleSearch(String query) {
    // Search suggestions are display titles; map back to the stable id once.
    final id = zikrIdForTitle(query) ?? query;
    final zikr = resolveZikr(id);
    if (zikr == null) return;
    ZikrDetailTarget(branch: ZikrBranch.home, zikrId: zikr.id).go(context);
  }

  @override
  Widget build(BuildContext context) {
    final islamicWeekday =
        ref.watch(prayerViewProvider.select((view) => view?.weekday)) ??
            DateTime.now().weekday;
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
        padding: const EdgeInsets.only(bottom: 16),
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
            AppTile(
              title: 'ورد يوم ${arabicWeekdays[dayIndex]}',
              leading: const AppTileLeadingIcon(
                icon: Icons.calendar_today_rounded,
              ),
              onTap: () => const TodaysZikrTarget().go(context),
            ),
            AppTile(
              title: 'دلائل الخيرات ورد يوم ${arabicWeekdays[dayIndex]}',
              leading: const AppTileLeadingIcon(
                icon: Icons.auto_stories_rounded,
              ),
              onTap: () {
                AppNav.goToZikr(
                  context,
                  ZikrBranch.home,
                  dalayilAlkhayratCollection[dayIndex].id,
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(Icons.favorite),
                  SizedBox(width: 8),
                  Text(
                    'المفضلة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
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
            EmptyBookmarks(),
          },
        ],
      ),
    );
  }
}

class EmptyBookmarks extends StatelessWidget {
  final VoidCallback? onExplore;

  const EmptyBookmarks({super.key, this.onExplore});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Column(
          children: [
            // Icon badge — the same folder_special as the section header
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              // icon
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.favorite_border,
                  size: 28,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'لا توجد مفضلات بعد',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'الأذكار التي تحفظها ستظهر هنا',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onExplore != null) ...[
              const SizedBox(height: 16),
              // Styled by your theme's elevatedButtonTheme automatically
              ElevatedButton.icon(
                onPressed: onExplore,
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: const Text('استكشف الأوراد'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
