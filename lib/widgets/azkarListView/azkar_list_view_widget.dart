import 'package:flutter/material.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/zikr_list_view_tile_widget.dart';

/// Builds the navigation target for a tile from its [title] and [index].
typedef ZikrTargetBuilder = ZikrTarget Function(String title, int index);

class AzkarListViewWidget extends StatelessWidget {
  const AzkarListViewWidget({
    super.key,
    // titles of collection
    required this.titles,
    required this.barTitle,
    required this.targetBuilder,
    this.scrollable = true,
  });

  final List<String> titles;
  final String barTitle;
  final ZikrTargetBuilder targetBuilder;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        physics: scrollable
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemCount: titles.length,
        shrinkWrap: true,
        itemBuilder: (context, index) {
          final title = titles[index];
          return ZikrListViewTile(
            title: title,
            target: targetBuilder(title, index),
          );
        });
  }
}
