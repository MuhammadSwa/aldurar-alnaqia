import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';

class ToggleThemeBtn extends StatelessWidget {
  const ToggleThemeBtn({super.key});

  Icon buildIcon(BuildContext context) {
    final Icon icon;
    switch (AdaptiveTheme.of(context).mode) {
      case AdaptiveThemeMode.system:
        icon = const Icon(Icons.brightness_auto_outlined);
        break;
      case AdaptiveThemeMode.light:
        icon = const Icon(Icons.light_mode_outlined);
        break;
      case AdaptiveThemeMode.dark:
        icon = const Icon(Icons.dark_mode_outlined);
        break;
    }
    return icon;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: buildIcon(context),
      onPressed: () {
        AdaptiveTheme.of(context).toggleThemeMode();
      },
    );
  }
}
