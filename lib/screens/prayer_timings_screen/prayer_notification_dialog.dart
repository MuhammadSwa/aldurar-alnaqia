import 'package:aldurar_alnaqia/services/prayer_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Explainer for the persistent prayer notification (Android, always-exact).
///
/// Opened from the bell icon when the notification is off. Enabling closes
/// the dialog; disabling happens straight from the bell without opening it.
///
/// Pops `true` when the notification was enabled so the bell icon refreshes.
class PrayerNotificationDialog extends ConsumerWidget {
  const PrayerNotificationDialog({super.key});

  /// Optimistic enable: the start call is reliable from a foreground tap,
  /// and the bell icon reflects the stored preference.
  Future<void> _enable(BuildContext context) async {
    await setPrayerNotificationEnabled(true);
    if (!context.mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Fixed dialog typography: deliberately NOT theme.textTheme.bodyMedium,
    // which follows the user zikr font-size setting (up to 40sp) and blows
    // up this dialog. Dialogs stay compact/readable.
    const titleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
    const bodyStyle = TextStyle(fontSize: 14, height: 1.7);
    const noteStyle = TextStyle(fontSize: 12.5, height: 1.6);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 24,
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications,
                size: 20,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            const Text('إشعار المواقيت', style: titleStyle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'يُبقي مواقيت الصلاة والعد التنازلي للصلاة القادمة ظاهر في شريط الإشعارات',
              style: bodyStyle.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'قد يتأخر ظهور الإشعار بضع ثوانٍ.',
              style: noteStyle.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () => _enable(context),
            child: const Text('تشغيل الإشعار'),
          ),
        ],
      ),
    );
  }
}
