import 'package:aldurar_alnaqia/widgets/azkarListView/bookmark_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ZikrListViewTile extends StatelessWidget {
  const ZikrListViewTile({
    super.key,
    required this.title,
    this.titles,
    this.index,
    required this.route,
  });
  final String title, route;
  final List<String>? titles;
  final int? index;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: const Icon(Icons.chevron_right),
      leading: BookmarkButton(bookmarkId: title),
      onTap: () {
        // TODO: pass titles to ZikrScreen
        context.go(route, extra: {'titles': titles, 'index': index});
      },
    );
  }
}
