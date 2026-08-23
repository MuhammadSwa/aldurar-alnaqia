import 'package:aldurar_alnaqia/utils/show_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aldurar_alnaqia/state/app_providers.dart';

class BookmarkButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isBookmarked =
        ref.watch(bookmarksProvider.select((bookmarks) => bookmarks.contains(bookmarkId)));

    return IconButton(
      highlightColor: Colors.lightGreenAccent,
      onPressed: () {
        final wasBookmark =
            ref.read(bookmarksProvider.notifier).toggleBookmark(bookmarkId);

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
  }
}
