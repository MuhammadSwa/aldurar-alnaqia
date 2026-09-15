import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

/// Icon button that cycles the appearance light -> dark -> system.
/// The icon always reflects the current [themeModeProvider] value.
class ToggleThemeBtn extends ConsumerWidget {
  const ToggleThemeBtn({super.key});

  Icon buildIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => const Icon(Icons.brightness_auto_outlined),
      ThemeMode.light => const Icon(Icons.light_mode_outlined),
      ThemeMode.dark => const Icon(Icons.dark_mode_outlined),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return IconButton(
      icon: buildIcon(mode),
      onPressed: () {
        ref.read(themeModeProvider.notifier).cycle();
      },
    );
  }
}
