import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

/// Drawer setting for appearance (المظهر) using the same title-only popup
/// pattern as the other drawer settings.
///
/// Shows only the title; the current choice is indicated with a tick inside
/// the popup menu. Reads/writes [themeModeProvider], the single source of
/// truth for the app's [ThemeMode].
class ThemeModeSettingWidget extends ConsumerWidget {
  const ThemeModeSettingWidget({super.key});

  String _label(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'فاتح',
      ThemeMode.dark => 'داكن',
      ThemeMode.system => 'تلقائي (النظام)',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final current = ref.watch(themeModeProvider);

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
        child: PopupMenuButton<ThemeMode>(
          initialValue: current,
          position: PopupMenuPosition.under,
          onSelected: (value) {
            ref.read(themeModeProvider.notifier).set(value);
          },
          itemBuilder: (context) => [
            for (final mode in ThemeMode.values)
              CheckedPopupMenuItem<ThemeMode>(
                value: mode,
                checked: mode == current,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _label(mode),
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
                    'المظهر',
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
