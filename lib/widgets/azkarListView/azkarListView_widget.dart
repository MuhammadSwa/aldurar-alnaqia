import 'package:flutter/material.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/zikrListViewTile_widget.dart';

class AzkarListViewWidget extends StatelessWidget {
  const AzkarListViewWidget({
    super.key,
    // titles of collection
    required this.titles,
    required this.route,
    required this.barTitle,
    this.scrollable = true,
  });
  final List<String> titles;
  final String route;
  final String barTitle;
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
            // TODO: pass titles here as well. optional. if there are titles swipe
            titles: titles,
            // TODO: pass index
            index: index,
            route: '$route/$title',
          );
        });
  }
}
