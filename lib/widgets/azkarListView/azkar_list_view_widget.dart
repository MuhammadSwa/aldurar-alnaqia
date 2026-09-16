import 'package:flutter/material.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/zikr_list_view_tile_widget.dart';

/// Builds the navigation target for a tile from its stable [zikrId] and [index].
typedef ZikrTargetBuilder = ZikrTarget Function(String zikrId, int index);

class AzkarListViewWidget extends StatelessWidget {
  const AzkarListViewWidget({
    super.key,
    // stable ids (zikr, collection, or day-wird ids)
    required this.zikrIds,
    this.titles,
    required this.barTitle,
    required this.targetBuilder,
    this.scrollable = true,
  });

  final List<String> zikrIds;

  /// Optional display overrides, parallel to [zikrIds]. When omitted,
  /// titles resolve from the registry.
  final List<String>? titles;
  final String barTitle;
  final ZikrTargetBuilder targetBuilder;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        physics: scrollable
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemCount: zikrIds.length,
        shrinkWrap: true,
        itemBuilder: (context, index) {
          final id = zikrIds[index];
          final title = titles != null && index < titles!.length
              ? titles![index]
              : null;
          return ZikrListViewTile(
            zikrId: id,
            title: title,
            target: targetBuilder(id, index),
          );
        });
  }
}
