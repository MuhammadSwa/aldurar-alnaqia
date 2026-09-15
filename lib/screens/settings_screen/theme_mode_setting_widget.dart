import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';

/// Drawer setting for appearance (المظهر) using the same title-only popup
/// pattern as the other drawer settings.
///
/// Shows only the title; the current choice is indicated with a tick inside
/// the popup menu.
class ThemeModeSettingWidget extends StatelessWidget {
  const ThemeModeSettingWidget({super.key});

  String _label(AdaptiveThemeMode mode) {
    return switch (mode) {
      AdaptiveThemeMode.light => 'فاتح',
      AdaptiveThemeMode.dark => 'داكن',
      AdaptiveThemeMode.system => 'تلقائي (النظام)',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final current = AdaptiveTheme.of(context).mode;

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
        child: PopupMenuButton<AdaptiveThemeMode>(
          initialValue: current,
          position: PopupMenuPosition.under,
          onSelected: (value) {
            AdaptiveTheme.of(context).setThemeMode(value);
          },
          itemBuilder: (context) => [
            for (final mode in AdaptiveThemeMode.values)
              CheckedPopupMenuItem<AdaptiveThemeMode>(
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
