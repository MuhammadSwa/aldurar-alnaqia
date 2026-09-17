import 'package:aldurar_alnaqia/common/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/setting_popup_tile.dart';

/// Drawer setting for appearance (المظهر) using the same title-only popup
/// pattern as the other drawer settings.
///
/// Shows only the title; the current choice is indicated with a tick inside
/// the popup menu. Reads/writes [themeModeProvider], the single source of
/// truth for the app's [ThemeMode].
class ThemeModeSettingWidget extends ConsumerWidget {
  const ThemeModeSettingWidget({super.key, this.cardStyle = SettingsCardStyle.classic});

  final SettingsCardStyle cardStyle;

  static String label(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'فاتح',
      ThemeMode.dark => 'داكن',
      ThemeMode.system => 'تلقائي (النظام)',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    return SettingPopupTile<ThemeMode>(
      title: 'المظهر',
      value: current,
      values: ThemeMode.values,
      labelFor: label,
      cardStyle: cardStyle,
      onSelected: (value) =>
          ref.read(themeModeProvider.notifier).set(value),
    );
  }
}
