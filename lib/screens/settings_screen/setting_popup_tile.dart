import 'package:aldurar_alnaqia/common/widgets/settings_card.dart';
import 'package:flutter/material.dart';

/// Generic title-only popup setting used by all drawer dropdowns.
///
/// Replaces the triplicated `PopupMenuButton + CheckedPopupMenuItem +
/// Align(centerRight) + Text` blocks in `ThemeModeSettingWidget`,
/// `FileActionSettingWidget` and `YousriaBeginningDayDropDown`.
class SettingPopupTile<T> extends StatelessWidget {
  const SettingPopupTile({
    super.key,
    required this.title,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onSelected,
  });

  final String title;
  final T value;
  final List<T> values;
  final String Function(T) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SettingsCard(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: PopupMenuButton<T>(
          initialValue: value,
          position: PopupMenuPosition.under,
          onSelected: onSelected,
          itemBuilder: (context) => [
            for (final v in values)
              CheckedPopupMenuItem<T>(
                value: v,
                checked: v == value,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    labelFor(v),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
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
