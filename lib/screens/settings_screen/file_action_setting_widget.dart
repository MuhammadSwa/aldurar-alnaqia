import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drawer setting that controls what happens when the user opens a file
/// (audio or book) that is not downloaded yet.
///
/// Single preference shared by both flows; the "تذكر الاختيار" checkbox in
/// [StreamOrDownloadDialog] writes to the same provider.
class FileActionSettingWidget extends ConsumerWidget {
  const FileActionSettingWidget({super.key});

  String _label(FileOpenAction action) {
    return switch (action) {
      FileOpenAction.ask => 'عرض الخيارات كل مرة',
      FileOpenAction.open => 'فتح مباشر دائمًا',
      FileOpenAction.download => 'تحميل دائمًا',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final current = ref.watch(fileOpenActionProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: PopupMenuButton<FileOpenAction>(
          initialValue: current,
          position: PopupMenuPosition.under,
          onSelected: (value) {
            ref.read(fileOpenActionProvider.notifier).set(value);
          },
          itemBuilder: (context) => [
            for (final action in FileOpenAction.values)
              CheckedPopupMenuItem<FileOpenAction>(
                value: action,
                checked: action == current,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _label(action),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
          ],
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'اختيارات التحميل',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
