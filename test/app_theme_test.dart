import 'package:aldurar_alnaqia/common/theme/app_theme.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemeModeStorage', () {
    test('round-trips each mode', () {
      for (final mode in ThemeMode.values) {
        expect(ThemeModeStorage.fromString(mode.toStorageString()), mode);
      }
    });

    test('unknown or null values fall back to system', () {
      expect(ThemeModeStorage.fromString(null), ThemeMode.system);
      expect(ThemeModeStorage.fromString(''), ThemeMode.system);
      expect(ThemeModeStorage.fromString('bogus'), ThemeMode.system);
    });
  });

  group('themeModeProvider', () {
    test('defaults to system with no persisted value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('set updates state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(themeModeProvider.notifier).set(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });

  group('AppTheme', () {
    test('light/dark factories carry the right brightness', () {
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().brightness, Brightness.dark);
    });

    test('fontSize parameter reaches bodyMedium', () {
      expect(AppTheme.light(fontSize: 28).textTheme.bodyMedium?.fontSize, 28);
      expect(AppTheme.dark(fontSize: 28).textTheme.bodyMedium?.fontSize, 28);
    });

    test('both themes share the component contract', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        expect(theme.useMaterial3, isTrue);
        expect(theme.elevatedButtonTheme.style, isNotNull);
        expect(
          theme.navigationBarTheme.backgroundColor,
          theme.colorScheme.secondaryContainer,
        );
        expect(
          theme.appBarTheme.backgroundColor,
          theme.colorScheme.secondaryContainer,
        );
      }
    });
  });
}
