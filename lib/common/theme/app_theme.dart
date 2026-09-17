import 'package:flutter/material.dart';

/// Single place where the app's visual themes are defined.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: AppTheme.light(fontSize: fontSize),
///   darkTheme: AppTheme.dark(fontSize: fontSize),
///   themeMode: themeMode, // from [themeModeProvider]
/// )
/// ```
///
/// The current [ThemeMode] (light/dark/system) is owned by
/// `themeModeProvider` (see `lib/state/app_providers.dart`) and persisted
/// via [SharedPreferencesService]. This file is intentionally stateless:
/// it only maps (brightness, font size) -> [ThemeData].
///
/// To extend (e.g. a high-contrast or sepia theme), add a new factory
/// next to [light]/[dark] and share component builders below instead of
/// copying a whole [ThemeData] block.
abstract final class AppTheme {
  AppTheme._();

  /// Font family used across the app (Arabic-first UI).
  static const String fontFamily = 'NotoNaskh';

  /// Fallback body font size. Must match the default in
  /// `SharedPreferencesService.getFontSize`.
  static const double defaultFontSize = 22;

  static const double _bodyLineHeight = 1.8;

  // -- Color schemes (built once; deriving them is not cheap) ---------------

  static final ColorScheme lightScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B6B4F),
    brightness: Brightness.light,
  ).copyWith(
    // Default tone 40 reads too dark; tone 50 of the same hue stays
    // 4.5:1 on white while feeling lighter.
    primary: const Color(0xFF318567),
  );

  static final ColorScheme darkScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4DD0C4),
    brightness: Brightness.dark,
  ).copyWith(
      // Default tone 80 reads washed-out; tone 70 of the same hue.
      primary: const Color(0xFF1A8980),);

  // -- Public factories -------------------------------------------------------

  /// Light theme. [fontSize] drives `bodyMedium` so the font-size setting
  /// applies app-wide (screens needing live updates additionally watch
  /// `fontSizeProvider` directly).
  static ThemeData light({double fontSize = defaultFontSize}) {
    return _build(
      scheme: lightScheme,
      brightness: Brightness.light,
      fontSize: fontSize,
      bodyMediumColor: Colors.black,
      bodySmallColor: Colors.grey.shade600,
      labelSmallColor: Colors.grey.shade600,
    );
  }

  /// Dark theme. See [light] for the [fontSize] contract.
  static ThemeData dark({double fontSize = defaultFontSize}) {
    return _build(
      scheme: darkScheme,
      brightness: Brightness.dark,
      fontSize: fontSize,
      bodyMediumColor: null,
      bodySmallColor: Colors.grey.shade400,
      labelSmallColor: null,
    );
  }

  /// Custom scheme factory (used by the temporary theme lab and any future
  /// theme picker). Text colors follow the same rules as [light]/[dark].
  static ThemeData fromScheme(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    return _build(
      scheme: scheme,
      brightness: scheme.brightness,
      fontSize: defaultFontSize,
      bodyMediumColor: isLight ? Colors.black : null,
      bodySmallColor: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
      labelSmallColor: isLight ? Colors.grey.shade600 : null,
    );
  }

  // -- Shared builder (edit component styling once, here) ---------------------

  static ThemeData _build({
    required ColorScheme scheme,
    required Brightness brightness,
    required double fontSize,
    required Color? bodyMediumColor,
    required Color? bodySmallColor,
    required Color? labelSmallColor,
  }) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: TextTheme(
        // for main non-bolded text in ZikrPage.
        bodyMedium: TextStyle(
          color: bodyMediumColor,
          fontSize: fontSize,
          height: _bodyLineHeight,
        ),
        // for footer and [^3], notes
        bodySmall: TextStyle(
          color: bodySmallColor,
          fontSize: 14,
        ),
        // used for title in timingsScreen
        titleMedium: const TextStyle(fontSize: 20),
        // Same size in both brightnesses (was dark-only 17).
        titleSmall: const TextStyle(fontSize: 17),
        // for numbering e.g. (12.)
        labelSmall: TextStyle(
          fontWeight: FontWeight.bold,
          color: labelSmallColor,
          fontSize: 20,
        ),
      ),
      appBarTheme: AppBarTheme(
        // Same container as the bottom NavigationBar (secondaryContainer).
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 60,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 24,
          color: scheme.onSecondaryContainer,
        ),
        iconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        actionsIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
      ),
      // Scheme-derived so both brightnesses adapt (was green[900] light vs
      // green[700] dark).
      iconTheme: IconThemeData(color: scheme.primary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStateProperty.all<EdgeInsets>(
            const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          ),
          backgroundColor:
              WidgetStateProperty.all<Color>(scheme.secondaryContainer),
          foregroundColor:
              WidgetStateProperty.all<Color>(scheme.onSecondaryContainer),
          shape: WidgetStateProperty.all<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        verticalOffset: 10,
        preferBelow: true,
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.all(8),
        enableFeedback: true,
        textStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      visualDensity: VisualDensity.comfortable,
      listTileTheme: ListTileThemeData(
        enableFeedback: true,
        iconColor: scheme.primary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        // Same as the audio mini-player. The selected-pill indicator uses
        // primary (not the default secondaryContainer) so it stays visible.
        backgroundColor: scheme.secondaryContainer,
        indicatorColor: scheme.primary,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: scheme.onSecondaryContainer),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Dark in both modes, still theme-derived: inverseSurface is dark
        // in light mode; in dark mode inverseSurface flips light, so use
        // a dark surface-container instead.
        backgroundColor: brightness == Brightness.light
            ? scheme.inverseSurface
            : scheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(
          color: brightness == Brightness.light
              ? scheme.onInverseSurface
              : scheme.onSurface,
          fontFamily: fontFamily,
        ),
        actionTextColor: brightness == Brightness.light
            ? scheme.onInverseSurface
            : scheme.onSurface,
      ),
    );
  }
}
