import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drawer setting that controls what happens when the user taps an audio
/// button for a file that is not downloaded yet.
///
/// Shows only the title; the current choice is indicated with a tick inside
/// the popup menu.
class AudioActionSettingWidget extends ConsumerWidget {
  const AudioActionSettingWidget({super.key});

  String _label(AudioOpenAction action) {
    return switch (action) {
      AudioOpenAction.ask => 'عرض الخيارات كل مرة',
      AudioOpenAction.stream => 'فتح مباشر دائمًا',
      AudioOpenAction.download => 'تحميل دائمًا',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final current = ref.watch(audioOpenActionProvider);

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
        child: PopupMenuButton<AudioOpenAction>(
          initialValue: current,
          position: PopupMenuPosition.under,
          onSelected: (value) {
            ref.read(audioOpenActionProvider.notifier).set(value);
          },
          itemBuilder: (context) => [
            for (final action in AudioOpenAction.values)
              CheckedPopupMenuItem<AudioOpenAction>(
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
                    'عند الضغط على زر الصوت',
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
