import 'package:flutter/material.dart';

/// Shared outer card for drawer settings and drawer list items.
///
/// Unifies the repeated `surfaceContainerHighest(0.3) + outline(0.2) +
/// radius12 + margin(16,4)` decoration previously copy-pasted in
/// `MyDrawer`, `ThemeModeSettingWidget`, `FileActionSettingWidget` and
/// `YousriaBeginningDayDropDown`.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
