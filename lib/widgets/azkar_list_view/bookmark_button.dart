import 'package:aldurar_alnaqia/common/helpers/snackbar.dart';
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
    final isBookmarked = ref.watch(
      bookmarksProvider.select((bookmarks) => bookmarks.contains(bookmarkId)),
    );

    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;

    return Semantics(
      button: true,
      label: isBookmarked ? 'إزالة من المحفوظات' : 'إضافة إلى المحفوظات',
      child: Tooltip(
        message: isBookmarked ? 'إزالة من المحفوظات' : 'إضافة إلى المحفوظات',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () {
              final wasBookmark = ref
                  .read(bookmarksProvider.notifier)
                  .toggleBookmark(bookmarkId);

              // Call the callback if provided
              onBookmarkToggled?.call(wasBookmark);

              // Show snackbar if enabled (helper hides the current one first).
              if (showSnackBarBool) {
                final message = wasBookmark
                    ? 'تم الحذف من المفضلة'
                    : 'تم الإضافة إلى المفضلة';
                showSnackBar(context, message);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: isBookmarked
                    ? accent.withValues(alpha: 0.15)
                    : scheme.surfaceContainerHighest,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, t) =>
                    ScaleTransition(scale: t, child: child),
                child: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  key: ValueKey(isBookmarked),
                  size: 20,
                  color: accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
