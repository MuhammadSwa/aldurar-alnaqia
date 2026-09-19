import 'package:material_ui/material_ui.dart';

/// Shown when the bell icon is tapped before prayer settings exist.
///
/// Pops `true` when the user wants to open the settings dialog, `false`
/// (or null) when it just dismisses.
class PrayerSetupRequiredDialog extends StatelessWidget {
  const PrayerSetupRequiredDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Fixed dialog typography: deliberately NOT theme.textTheme.bodyMedium,
    // which follows the user zikr font-size setting and blows up dialogs.
    const titleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
    const bodyStyle = TextStyle(fontSize: 14, height: 1.7);
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
                Icons.settings,
                size: 20,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            const Text('إعدادات المواقيت', style: titleStyle),
          ],
        ),
        content: Text(
          'برجاء إعداد المواقيت أولاً قبل تشغيل الإشعار.',
          style: bodyStyle.copyWith(color: colors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إعدادات المواقيت'),
          ),
        ],
      ),
    );
  }
}
