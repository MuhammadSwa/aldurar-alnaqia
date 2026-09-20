import 'package:aldurar_alnaqia/services/shared_prefs.dart'
    show AppearancePrefs;
import 'package:material_ui/material_ui.dart';

// flutter to hex: https://jonas-rodehorst.dev/tools/flutter-color-from-hex

/// Single place where the app's visual themes are defined.
///
/// The current [ThemeMode] (light/dark/system) is owned by
/// `themeModeProvider` (see `lib/state/app_providers.dart`) and persisted
/// via `SharedPreferencesService`. This file is intentionally stateless:
/// it only maps (brightness, font size) -> [ThemeData].
///
/// To extend (e.g. a high-contrast or sepia theme), add a new factory
/// next to [light]/[dark] and share component builders below instead of
/// copying a whole [ThemeData] block.
abstract final class AppTheme {
  AppTheme._();

  /// Font family used across the app
  static const String fontFamily = 'NotoNaskh';

  /// Fallback body font size. Alias of [AppearancePrefs.defaultFontSize]
  /// so the theme default cannot drift from the stored-prefs default.
  static const double defaultFontSize = AppearancePrefs.defaultFontSize;

  static const double _bodyLineHeight = 1.8;

  // -- Color schemes (explicit consts)
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF318567),
    onPrimary: Color(0xFFC1E3D5),
    primaryContainer: Color(0xFFA7F2D1),
    onPrimaryContainer: Color(0xFF00513B),
    primaryFixed: Color(0xFFA7F2D1),
    primaryFixedDim: Color(0xFF8BD6B5),
    onPrimaryFixed: Color(0xFF002116),
    onPrimaryFixedVariant: Color(0xFF00513B),
    secondary: Color(0xFF4C6358),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFCFE9DA),
    onSecondaryContainer: Color(0xFF354B41),
    secondaryFixed: Color(0xFFCFE9DA),
    secondaryFixedDim: Color(0xFFB3CCBF),
    onSecondaryFixed: Color(0xFF092017),
    onSecondaryFixedVariant: Color(0xFF354B41),
    tertiary: Color(0xFF3E6374),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFC2E8FC),
    onTertiaryContainer: Color(0xFF254B5C),
    tertiaryFixed: Color(0xFFC2E8FC),
    tertiaryFixedDim: Color(0xFFA6CCE0),
    onTertiaryFixed: Color(0xFF001F2A),
    onTertiaryFixedVariant: Color(0xFF254B5C),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: Color(0xFFF5FBF5),
    onSurface: Color(0xFF171D1A),
    surfaceDim: Color(0xFFD6DBD6),
    surfaceBright: Color(0xFFF5FBF5),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFEFF5F0),
    surfaceContainer: Color(0xFFEAEFEA),
    surfaceContainerHigh: Color(0xFFE4EAE4),
    surfaceContainerHighest: Color(0xFFDEE4DF),
    onSurfaceVariant: Color(0xFF404944),
    outline: Color(0xFF707974),
    outlineVariant: Color(0xFFBFC9C2),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2C322E),
    onInverseSurface: Color(0xFFECF2ED),
    inversePrimary: Color(0xFF8BD6B5),
    surfaceTint: Color(0xFF1C6B50),
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF1B7770),
    onPrimary: Color(0xFF003733),
    primaryContainer: Color(0xFF00504A),
    onPrimaryContainer: Color(0xFF9DF2E8),
    primaryFixed: Color(0xFF9DF2E8),
    primaryFixedDim: Color(0xFF81D5CC),
    onPrimaryFixed: Color(0xFF00201D),
    onPrimaryFixedVariant: Color(0xFF00504A),
    secondary: Color(0xFFB1CCC8),
    onSecondary: Color(0xFF1C3532),
    secondaryContainer: Color(0xFF324B48),
    onSecondaryContainer: Color(0xFFCCE8E4),
    secondaryFixed: Color(0xFFCCE8E4),
    secondaryFixedDim: Color(0xFFB1CCC8),
    onSecondaryFixed: Color(0xFF051F1D),
    onSecondaryFixedVariant: Color(0xFF324B48),
    tertiary: Color(0xFFAFC9E7),
    onTertiary: Color(0xFF17324A),
    tertiaryContainer: Color(0xFF2F4961),
    onTertiaryContainer: Color(0xFFCEE5FF),
    tertiaryFixed: Color(0xFFCEE5FF),
    tertiaryFixedDim: Color(0xFFAFC9E7),
    onTertiaryFixed: Color(0xFF001D33),
    onTertiaryFixedVariant: Color(0xFF2F4961),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF0E1514),
    onSurface: Color(0xFFDDE4E2),
    surfaceDim: Color(0xFF0E1514),
    surfaceBright: Color(0xFF343A39),
    surfaceContainerLowest: Color(0xFF090F0F),
    surfaceContainerLow: Color(0xFF161D1C),
    surfaceContainer: Color(0xFF1A2120),
    surfaceContainerHigh: Color(0xFF252B2A),
    surfaceContainerHighest: Color(0xFF303635),
    onSurfaceVariant: Color(0xFFBEC9C6),
    outline: Color(0xFF899391),
    outlineVariant: Color(0xFF3F4947),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFDDE4E2),
    onInverseSurface: Color(0xFF2B3231),
    inversePrimary: Color(0xFF006A63),
    surfaceTint: Color(0xFF81D5CC),
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
        // Small metadata (sizes, stats). Nothing in the app may repurpose
        // this for body-size text: numbering is styled inline in
        // ZikrInlineText, and Material components read this as-is.
        labelSmall: TextStyle(
          fontWeight: FontWeight.w500,
          color: labelSmallColor,
          fontSize: 12,
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
              borderRadius: BorderRadius.circular(10),
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
