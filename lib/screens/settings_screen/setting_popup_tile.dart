import 'package:aldurar_alnaqia/common/widgets/settings_card.dart';
import 'package:material_ui/material_ui.dart';

/// Generic title-only popup setting used by all drawer dropdowns.
///
/// Replaces the triplicated `PopupMenuButton + CheckedPopupMenuItem +
/// Align(centerRight) + Text` blocks in `ThemeModeSettingWidget`,
/// `FileActionSettingWidget` and `YousriaBeginningDayDropDown`.
class SettingPopupTile<T> extends StatelessWidget {
  const SettingPopupTile({
    required this.title,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onSelected,
    super.key,
    this.cardStyle = SettingsCardStyle.classic,
    this.leading,
    this.trailingStyle = 0,
  });

  final String title;
  final T value;
  final List<T> values;
  final String Function(T) labelFor;
  final ValueChanged<T> onSelected;

  /// TEMP LAB: outer card variation (one per drawer row).
  final SettingsCardStyle cardStyle;

  /// TEMP LAB: optional leading icon chip to preview icon treatments.
  final Widget? leading;

  /// TEMP LAB: 0 = arrow-down, 1 = chevron in circle, 2 = no trailing.
  final int trailingStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SettingsCard(
      style: cardStyle,
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
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cardStyle == SettingsCardStyle.tonal
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              _buildTrailing(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrailing(ColorScheme colorScheme) {
    switch (trailingStyle) {
      case 1:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary.withValues(alpha: 0.12),
          ),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: colorScheme.primary,
            size: 18,
          ),
        );
      case 2:
        return const SizedBox.shrink();
      default:
        return Icon(
          Icons.keyboard_arrow_down_rounded,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        );
    }
  }
}
