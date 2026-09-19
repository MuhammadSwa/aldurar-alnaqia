import 'package:material_ui/material_ui.dart';

/// Shared outer card for drawer settings and drawer list items.
///
/// Unified on [SettingsCardStyle.outlined]: outlined border + much-transparent
/// `secondaryContainer` tint. Other values are kept for experimentation.
enum SettingsCardStyle {
  classic,
  tonal,
  outlined,
  elevated,
  flat,
  accent,
  pill,
}

class SettingsCard extends StatelessWidget {
  const SettingsCard(
      {required this.child, super.key, this.style = SettingsCardStyle.classic,});

  final Widget child;
  final SettingsCardStyle style;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (style) {
      case SettingsCardStyle.tonal:
        // 2. Solid tonal fill, no border, bigger radius.
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: colorScheme.secondaryContainer,
          ),
          child: child,
        );
      case SettingsCardStyle.outlined:
        // Unified choice: outlined border + much-transparent secondary tint.
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.secondaryContainer.withValues(alpha: 0.18),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
          child: child,
        );
      case SettingsCardStyle.elevated:
        // 4. Solid surface with shadow.
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: colorScheme.surfaceContainerLow,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        );
      case SettingsCardStyle.flat:
        // 5. No card at all — transparent minimal row.
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: Colors.transparent,
          child: child,
        );
      case SettingsCardStyle.accent:
        // 6. Classic card + start (right in RTL) accent strip.
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            border: Border(
              right: BorderSide(color: colorScheme.primary, width: 4),
              top: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
                width: 0.5,
              ),
              left: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
                width: 0.5,
              ),
              bottom: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: child,
        );
      case SettingsCardStyle.pill:
        // 7. High-contrast pill with thicker border + larger radius.
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          child: child,
        );
      case SettingsCardStyle.classic:
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
          child: child,
        );
    }
  }
}
