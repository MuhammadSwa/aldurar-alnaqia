import 'package:flutter/material.dart';
import 'package:aldurar_alnaqia/services/yousria_cycle.dart';

/// Educates about the 6-day Yousria cycle and offers one-tap setup.
/// Shown on every day wird page until dismissed.
class YousriaBanner extends StatelessWidget {
  const YousriaBanner({
    super.key,
    required this.yousria,
    required this.onSetup,
    required this.onHide,
  });

  final YousriaDayInfo yousria;
  final VoidCallback onSetup;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 20,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الصلوات اليسرية: ${yousria.title}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'اختر صلوات اليوم وسيتم حفظ ترتيب الصلوات تلقائيًّا',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onHide,
                  child: const Text('إخفاء'),
                ),
                const SizedBox(width: 4),
                FilledButton.tonal(
                  onPressed: onSetup,
                  child: const Text('تحديد البداية'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Transient confirmation shown for a few seconds after the banner hides.
class YousriaHideConfirmation extends StatelessWidget {
  const YousriaHideConfirmation({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'يمكنك تغيير البداية لاحقًا من القائمة الجانبية.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
