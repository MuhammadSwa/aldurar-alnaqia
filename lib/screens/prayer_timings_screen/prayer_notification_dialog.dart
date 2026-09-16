import 'package:aldurar_alnaqia/services/prayer_notification_service.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Explainer + control for the persistent prayer notification (Android).
///
/// Opened from the bell icon when the notification is off. Teaches what the
/// notification does and what the precise-alert toggle does, in one place.
/// Enabling closes the dialog; disabling happens straight from the bell
/// without opening it.
///
/// Pops `true` when anything changed so the bell icon can refresh.
class PrayerNotificationDialog extends ConsumerStatefulWidget {
  const PrayerNotificationDialog({super.key});

  @override
  ConsumerState<PrayerNotificationDialog> createState() =>
      _PrayerNotificationDialogState();
}

class _PrayerNotificationDialogState
    extends ConsumerState<PrayerNotificationDialog> {
  late bool _preciseAlerts = SharedPreferencesService.getPrayerPreciseAlerts();
  bool _changed = false;

  /// Optimistic enable: the start call is reliable from a foreground tap,
  /// and the bell icon reflects the stored preference.
  Future<void> _enable() async {
    await setPrayerNotificationEnabled(true);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _setPrecise(bool value) async {
    setState(() {
      _preciseAlerts = value;
      _changed = true;
    });
    // Applies live when the notification runs; otherwise takes effect
    // the next time it is enabled.
    await SharedPreferencesService.setPrayerPreciseAlerts(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Fixed dialog typography: deliberately NOT theme.textTheme.bodyMedium,
    // which follows the user zikr font-size setting (up to 40sp) and blows
    // up this dialog (see screenshot). Dialogs stay compact/readable.
    const titleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
    const bodyStyle = TextStyle(fontSize: 14, height: 1.7);
    const toggleTitleStyle = TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
    );
    const toggleSubStyle = TextStyle(fontSize: 12.5, height: 1.6);
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'يُبقي مواقيت الصلاة والعد التنازلي للصلاة القادمة ظاهر في الإشعارات حتى بعد إغلاق التطبيق',
                style: bodyStyle.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'تنبيه دقيق عند دخول الوقت',
                            style: toggleTitleStyle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'صوت لحظة دخول الوقت. إيقافه يوفّر البطارية لكن قد يتأخر التنبيه بضع دقائق.',
                            style: toggleSubStyle.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _preciseAlerts,
                      onChanged: (value) => _setPrecise(value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_changed),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: _enable,
            child: const Text('تشغيل الإشعار'),
          ),
        ],
      ),
    );
  }
}
