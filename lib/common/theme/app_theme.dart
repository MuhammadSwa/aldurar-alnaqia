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
  static const double defaultFontSize = 20;

  static const double _bodyLineHeight = 1.8;

  // -- Color schemes (built once; deriving them is not cheap) ---------------

  static final ColorScheme lightScheme = ColorScheme.fromSeed(
    // used for table borders
    secondaryFixed: Colors.greenAccent,
    seedColor: Colors.green,
    brightness: Brightness.light,
  );

  static final ColorScheme darkScheme = ColorScheme.fromSeed(
    // used for table borders
    secondaryFixed: Colors.greenAccent,
    seedColor: Colors.greenAccent,
    brightness: Brightness.dark,
  );

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
      iconColor: Colors.green.shade900,
      navIconColor: Colors.green.shade900,
      // NOTE: light intentionally has no titleSmall override and uses the
      // default toolbar height — preserved from the previous theme set.
      titleSmallFontSize: null,
      appBarToolbarHeight: null,
      appBarTitleHeight: null,
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
      iconColor: Colors.green.shade700,
      navIconColor: Colors.green,
      titleSmallFontSize: 17,
      appBarToolbarHeight: 60,
      appBarTitleHeight: 2,
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
    required Color? iconColor,
    required Color? navIconColor,
    required double? titleSmallFontSize,
    required double? appBarToolbarHeight,
    required double? appBarTitleHeight,
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
        // used for title in timingsScreen dialog (dark only)
        titleSmall: titleSmallFontSize == null
            ? null
            : TextStyle(fontSize: titleSmallFontSize),
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
        toolbarHeight: appBarToolbarHeight,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 24,
          height: appBarTitleHeight,
          color: scheme.onSecondaryContainer,
        ),
        iconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        actionsIconTheme:
            IconThemeData(color: scheme.onSecondaryContainer),
      ),
      iconTheme: IconThemeData(color: iconColor),
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
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.all(8),
        enableFeedback: true,
        textStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      visualDensity: VisualDensity.comfortable,
      listTileTheme: ListTileThemeData(
        enableFeedback: true,
        iconColor: Colors.green[700],
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
        surfaceTintColor: Colors.green.shade900,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: navIconColor),
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
        backgroundColor: Colors.green[900],
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: fontFamily,
        ),
        actionTextColor: Colors.white,
      ),
    );
  }
}
