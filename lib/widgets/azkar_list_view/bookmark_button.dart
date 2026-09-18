import 'package:aldurar_alnaqia/common/helpers/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aldurar_alnaqia/state/app_providers.dart';

class BookmarkButton extends ConsumerStatefulWidget {
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
  ConsumerState<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends ConsumerState<BookmarkButton> {
  bool _hover = false;
  bool _pressed = false;

  bool get _active => _hover || _pressed;

  @override
  Widget build(BuildContext context) {
    final isBookmarked = ref.watch(
      bookmarksProvider.select(
        (bookmarks) => bookmarks.contains(widget.bookmarkId),
      ),
    );

    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final baseColor = isBookmarked
        ? accent.withValues(alpha: 0.15)
        : scheme.surfaceContainerHighest;
    // Slight intensify on hover/press (mouse hover or finger touch).
    final backgroundColor = _active
        ? Color.alphaBlend(accent.withValues(alpha: 0.08), baseColor)
        : baseColor;

    return Semantics(
      button: true,
      label: isBookmarked ? 'إزالة من المحفوظات' : 'إضافة إلى المحفوظات',
      child: Tooltip(
        message: isBookmarked ? 'إزالة من المحفوظات' : 'إضافة إلى المحفوظات',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onHighlightChanged: (highlighted) =>
                  setState(() => _pressed = highlighted),
              onTap: () {
                final wasBookmark = ref
                    .read(bookmarksProvider.notifier)
                    .toggleBookmark(widget.bookmarkId);

                // Call the callback if provided
                widget.onBookmarkToggled?.call(wasBookmark);

                // Show snackbar if enabled (helper hides the current one first).
                if (widget.showSnackBarBool) {
                  final message = wasBookmark
                      ? 'تم الحذف من المفضلة'
                      : 'تم الإضافة إلى المفضلة';
                  showSnackBar(context, message);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: backgroundColor,
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
      ),
    );
  }
}
