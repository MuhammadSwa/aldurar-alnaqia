import 'package:aldurar_alnaqia/utils/showSnackbar.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/bookmarks_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BookmarkButton extends StatelessWidget {
  const BookmarkButton({
    super.key,
    required this.bookmarkId,
    this.onBookmarkToggled,
    this.showSnackBarBool = true,
  });

  final String bookmarkId;
  final Function(bool wasBookmarked)? onBookmarkToggled;
  final bool showSnackBarBool;

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
            if (showSnackBarBool) {
              final message = wasBookmark
                  ? 'تم الحذف من المحفوظات'
                  : 'تم الإضافة إلى المحفوظات';
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              showSnackBar(context, message);
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
