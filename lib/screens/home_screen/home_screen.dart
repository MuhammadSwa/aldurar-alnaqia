import 'dart:async' show unawaited;

import 'package:aldurar_alnaqia/common/helpers/helpers.dart';
import 'package:aldurar_alnaqia/common/widgets/app_tile.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/models/consts/dalayil_alkhayrat_collection.dart';
import 'package:aldurar_alnaqia/prayer/prayer_providers.dart';
import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/router/nav_helpers.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/zikr_list_view_tile_widget.dart';
import 'package:aldurar_alnaqia/widgets/search_widget.dart';
import 'package:aldurar_alnaqia/widgets/swipe_drawer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timezone/timezone.dart' as tz;

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
    // Full view (not just weekday): the Friday Hadra / Asr-wird gates need
    // today's Dhuhr + Asr times, and watching the view rebuilds this screen
    // at every prayer boundary via the nudge timer (Dhuhr show, Asr show,
    // Maghrib hide when the Islamic weekday flips to Saturday).
    final view = ref.watch(prayerViewProvider);
    final islamicWeekday = view?.weekday ?? DateTime.now().weekday;
    final dayIndex = islamicWeekday - 1;

    final fridayTiles = _fridayTilesVisibility(view);
    final showHadra = fridayTiles.showHadra;
    final showAsrWird = fridayTiles.showAsrWird;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدرر النقية'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => SwipeDrawer.of(context).open(),
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
            // Friday-only tiles, prayer-gated. Hadra from Dhuhr, Asr wird
            // from Asr; both vanish at Maghrib when the Islamic weekday
            // flips to Saturday (same rollover as the tiles above).
            // Unconfigured (view == null): hidden — without Dhuhr/Asr times
            // there is no correct gate, so never guess.
            if (showHadra)
              AppTile(
                title: 'الحضرة الصديقية',
                leading: const AppTileLeadingIcon(
                  icon: Icons.groups_rounded,
                ),
                onTap: () => const ZikrCollectionViewTarget(
                  ZikrBranch.home,
                  collection: 'hadra',
                ).go(context),
              ),
            if (showAsrWird)
              AppTile(
                title: 'ورد عصر يوم الجمعة',
                leading: const AppTileLeadingIcon(
                  icon: Icons.wb_sunny_outlined,
                ),
                onTap: () => AppNav.goToZikr(
                  context,
                  ZikrBranch.home,
                  'wird-asr-jumua',
                ),
              ),

            AppTile(
              title: dalayilAlkhayratCollection[dayIndex].title,
              // maxTitleLines: 1,
              subtitle: 'ورد يوم ${arabicWeekdays[dayIndex]}',
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

/// Friday-only home tiles visibility. Pure for tests.
class FridayTilesVisibility {
  const FridayTilesVisibility({
    required this.showHadra,
    required this.showAsrWird,
  });

  static const hidden =
      FridayTilesVisibility(showHadra: false, showAsrWird: false);

  final bool showHadra;
  final bool showAsrWird;
}

/// Friday-only home tiles visibility.
FridayTilesVisibility fridayTilesVisibility({
  required int islamicWeekday,
  required DateTime now,
  required DateTime? dhuhr,
  required DateTime? asr,
}) {
  // From Friday's Maghrib the Islamic weekday is Saturday — this also
  // handles hiding everything afterwards.
  if (islamicWeekday != DateTime.friday) return FridayTilesVisibility.hidden;
  // Before civil Friday the schedule still carries Thursday's Dhuhr/Asr;
  // there is no Friday prayer time to gate on yet.
  if (now.weekday != DateTime.friday) return FridayTilesVisibility.hidden;
  // Without Dhuhr/Asr times there is no correct gate, so never guess.
  if (dhuhr == null || asr == null) return FridayTilesVisibility.hidden;
  return FridayTilesVisibility(
    showHadra: !now.isBefore(dhuhr),
    showAsrWird: !now.isBefore(asr),
  );
}

FridayTilesVisibility _fridayTilesVisibility(PrayerView? view) {
  if (view == null) return FridayTilesVisibility.hidden;
  // Live clock (not view.today): a rebuild triggered by e.g. a bookmark
  // change must still gate on the actual instant, not a stale snapshot.
  final now = tz.TZDateTime.now(view.schedule.civilDate.location);
  return fridayTilesVisibility(
    islamicWeekday: view.weekday,
    now: now,
    dhuhr: view.schedule.events[PrayerEventId.dhuhr]?.time,
    asr: view.schedule.events[PrayerEventId.asr]?.time,
  );
}

class BookmarksTilesHomeScreen extends ConsumerWidget {
  const BookmarksTilesHomeScreen({super.key});

  static int? _dayFromBookmark(String bookmark) {
    if (!bookmark.startsWith('day-wird-')) return null;
    final day = int.tryParse(bookmark.split('-').last);
    if (day != null && dayWirdTitles.containsKey(day)) return day;
    return null;
  }

  static ZikrListViewTile _tileFor(
    String bookmark,
    List<String> orphanIds,
    Map<String, int> orphanIndexById,
  ) {
    if (bookmark == weekCollectionBookmarkId) {
      return const ZikrListViewTile(
        key: ValueKey(weekCollectionBookmarkId),
        zikrId: weekCollectionBookmarkId,
        title: 'أوراد الأسبوع',
        target: WeekCollectionTarget(ZikrBranch.home),
      );
    }
    final day = _dayFromBookmark(bookmark);
    if (day != null) {
      return ZikrListViewTile(
        key: ValueKey(bookmark),
        zikrId: bookmark,
        title: dayWirdTitles[day],
        target: DayWirdTarget(ZikrBranch.home, day: day),
      );
    }
    if (collectionById.containsKey(bookmark)) {
      return ZikrListViewTile(
        key: ValueKey(bookmark),
        zikrId: bookmark,
        target: ZikrCollectionViewTarget(
          ZikrBranch.home,
          collection: bookmark,
        ),
      );
    }
    return ZikrListViewTile(
      key: ValueKey(bookmark),
      zikrId: bookmark,
      target: ZikrDetailTarget(
        branch: ZikrBranch.home,
        zikrId: bookmark,
        zikrIds: orphanIds,
        index: orphanIndexById[bookmark] ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);

    if (bookmarks.isEmpty) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Column(children: [EmptyBookmarks()]),
      );
    }

    // Swipe context for individual zikrs: bookmark order, filtered to
    // non-collection ids so detail pages still swipe across bookmarked
    // zikrs only.
    final orphanIds = <String>[];
    for (final bookmark in bookmarks) {
      if (_dayFromBookmark(bookmark) != null) continue;
      if (bookmark == weekCollectionBookmarkId) continue;
      if (collectionById.containsKey(bookmark)) continue;
      orphanIds.add(bookmark);
    }
    final orphanIndexById = <String, int>{};
    for (var i = 0; i < orphanIds.length; i++) {
      orphanIndexById.putIfAbsent(orphanIds[i], () => i);
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bookmarks.length,
      onReorderItem: (oldIndex, newIndex) =>
          ref.read(bookmarksProvider.notifier).reorder(oldIndex, newIndex),
      // Haptic tick the moment the long-press becomes a drag.
      onReorderStart: (_) {
        unawaited(HapticFeedback.mediumImpact());
      },
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = Curves.easeOut.transform(animation.value);
          return Transform.scale(
            scale: 1 + 0.02 * t,
            child: Material(
              elevation: 6 * t,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: child,
            ),
          );
        },
        child: child,
      ),
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        return _tileFor(bookmark, orphanIds, orphanIndexById);
      },
    );
  }
}

class EmptyBookmarks extends StatelessWidget {
  const EmptyBookmarks({super.key, this.onExplore});
  final VoidCallback? onExplore;

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
