import 'package:material_ui/material_ui.dart';

/// Reusable destructive confirmation dialog.
///
/// Returns true when the user confirms, false on cancel or dismiss.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmLabel = 'حذف',
  String cancelLabel = 'إلغاء',
  IconData icon = Icons.delete_outline_rounded,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      return AlertDialog(
        icon: Icon(icon, color: scheme.error),
        // Fixed compact styles: dialog chrome stays readable regardless of
        // the user's (large) zikr reading-font setting.
        title: Text(title, style: theme.textTheme.titleMedium),
        content: Text(content, style: theme.textTheme.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
