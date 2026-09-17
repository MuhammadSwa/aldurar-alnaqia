import 'package:aldurar_alnaqia/common/widgets/app_tile.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/bookmark_button.dart';
import 'package:flutter/material.dart';

/// A single azkar list entry styled with [AppTile] (V5Outlined).
/// Navigation is expressed as a typed [ZikrTarget] instead of a raw
/// path string, so ids are always encoded correctly. Display titles
/// resolve from stable ids.
class ZikrListViewTile extends StatelessWidget {
  const ZikrListViewTile({
    super.key,
    required this.zikrId,
    this.title,
    required this.target,
    this.margin,
  });

  /// Stable id ([Zikr.id], collection id, or day-wird/week bookmark id).
  final String zikrId;

  /// Display override. Defaults to the resolved zikr/collection/day title.
  final String? title;

  final ZikrTarget target;

  /// Optional margin override. Defaults to [AppTile]'s standard margin.
  final EdgeInsetsGeometry? margin;

  static String displayTitle(String id, [String? override]) {
    if (override != null) return override;
    final zikr = resolveZikr(id);
    if (zikr != null) return zikr.title;
    final collection = resolveCollection(id);
    if (collection != null) return collection.title;
    if (id == weekCollectionBookmarkId) return 'أوراد الأسبوع';
    if (id.startsWith('day-wird-')) {
      final day = int.tryParse(id.split('-').last);
      if (day != null && dayWirdTitles.containsKey(day)) {
        return dayWirdTitles[day]!;
      }
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return AppTile(
      title: displayTitle(zikrId, title),
      leading: BookmarkButton(bookmarkId: zikrId),
      onTap: () => target.go(context),
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    );
  }
}
