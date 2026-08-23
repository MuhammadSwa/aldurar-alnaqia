import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/bookmark_button.dart';
import 'package:flutter/material.dart';

/// A single azkar list entry. Navigation is expressed as a typed
/// [ZikrTarget] instead of a raw path string, so titles with spaces or
/// special characters are always encoded correctly.
class ZikrListViewTile extends StatelessWidget {
  const ZikrListViewTile({
    super.key,
    required this.title,
    required this.target,
  });

  final String title;
  final ZikrTarget target;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: const Icon(Icons.chevron_right),
      leading: BookmarkButton(bookmarkId: title),
      onTap: () => target.go(context),
    );
  }
}
