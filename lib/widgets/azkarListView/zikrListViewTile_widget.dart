import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/bookmarks_controller.dart';

class ZikrListViewTile extends StatelessWidget {
  const ZikrListViewTile({
    super.key,
    required this.title,
    required this.route,
  });
  final String title, route;

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
        context.go(route);
      },
    );
  }
}

class BookmarkButton extends StatelessWidget {
  const BookmarkButton({
    super.key,
    required this.bookmarkId,
    this.onBookmarkToggled,
    this.showSnackBar = true,
  });

  final String bookmarkId;
  final Function(bool wasBookmarked)? onBookmarkToggled;
  final bool showSnackBar;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BookmarksController>(
      builder: (controller) {
        final isBookmarked = controller.isBookmarked(bookmarkId);

        return IconButton(
          highlightColor: Colors.lightGreenAccent,
          onPressed: () {
            final wasBookmark = controller.toggleBookmark(bookmarkId);

            // Call the callback if provided
            onBookmarkToggled?.call(wasBookmark);

            // Show snackbar if enabled
            if (showSnackBar) {
              final message = wasBookmark
                  ? 'تم الحذف من المحفوظات'
                  : 'تم الإضافة إلى المحفوظات';
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(milliseconds: 700),
                  content: Text(message),
                ),
              );
            }
          },
          icon: isBookmarked
              ? const Icon(Icons.bookmark)
              : const Icon(Icons.bookmark_outline_rounded),
        );
      },
    );
  }
}
