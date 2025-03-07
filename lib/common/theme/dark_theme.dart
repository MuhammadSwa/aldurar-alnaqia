import 'package:flutter/material.dart';
import 'package:get/instance_manager.dart';
import 'package:yosria/screens/settings_screen/font_settings_widget.dart';

abstract class BaseTheme {
  static final double bodyMediumFontSize = Get.put(FontController()).fontSize.value;
  static const double bodyMediumHeight = 1.8;

  static const double bodySmallFontSize = 14;
  static const double titleMediumfontSize = 24;

  // static ThemeData get baseTheme => ThemeData(
  // useMaterial3: true,
  // fontFamily: 'NotoNaskh',
  // appBarTheme: const AppBarTheme(
  //   toolbarHeight: 60,
  //   titleTextStyle: TextStyle(
  //     fontFamily: 'NotoNaskh',
  //     fontSize: 24,
  //     height: 2,
  //   ),
  // ),
  // );
}

final darkTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'NotoNaskh',
  textTheme: TextTheme(
    // for main non-bolded text in ZikrPage.
    bodyMedium: TextStyle(
      // TODO: size and height should be from provider from shared_prefs, change from settings
      color: Colors.grey.shade100,
      fontSize: Get.put(FontController().fontSize.value),
      height: BaseTheme.bodyMediumHeight,
    ),
    // fot footer and [^3], notes
    bodySmall: TextStyle(
      color: Colors.grey.shade400,
      // TODO: calc this from main fontSize
      fontSize: BaseTheme.bodySmallFontSize,
    ),
    // used for title in timingsScreen
    titleMedium: const TextStyle(
      fontSize: BaseTheme.titleMediumfontSize,
    ),
    // used for title in timingsScreen dialog
    titleSmall: const TextStyle(
      fontSize: 17,
    ),
    // for numbering e.g. (12.)
    labelSmall: TextStyle(
      fontWeight: FontWeight.bold,
      // TODO: change based on theme
      color: Colors.grey.shade400,
      // TODO: calc this from main fontSize
      fontSize: 20,
    ),
  ),

  colorScheme: ColorScheme.fromSeed(
    // used for table borders
    secondaryFixed: Colors.greenAccent,
    seedColor: Colors.greenAccent,
    brightness: Brightness.dark,
  ),
  appBarTheme: const AppBarTheme(
    toolbarHeight: 60,
    titleTextStyle: TextStyle(
      fontFamily: 'NotoNaskh',
      fontSize: 24,
      height: 2,
    ),
  ),
  iconTheme: IconThemeData(
    color: Colors.green.shade700,
  ),
  // platform: TargetPlatform.android,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      padding: WidgetStateProperty.all<EdgeInsets>(
        const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
      foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
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
      // side: BorderSide(color: Colors.green.shade900, width: 1),
    ),
  ),
  // scrollbarTheme: const ScrollbarThemeData(
  //   thumbColor: MaterialStatePropertyAll(Colors.red),
  //   trackColor: MaterialStatePropertyAll(Colors.red),
  //   trackBorderColor: MaterialStatePropertyAll(Colors.red),
  //   radius: Radius.circular(10),
  //   thickness: MaterialStatePropertyAll(10),
  //   thumbVisibility: MaterialStatePropertyAll(true),
  //   trackVisibility: MaterialStatePropertyAll(true),
  //   interactive: true,
  // ),
  navigationBarTheme: NavigationBarThemeData(
    surfaceTintColor: Colors.green.shade900,
    iconTheme: const WidgetStatePropertyAll(
      IconThemeData(
        color: Colors.green,
        // fill: 120,
      ),
    ),
    labelTextStyle: const MaterialStatePropertyAll(
      TextStyle(
        fontSize: 12,
      ),
    ),
  ),

  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.green[900],
    contentTextStyle:
        const TextStyle(color: Colors.white, fontFamily: 'NotoNaskh'),
    actionTextColor: Colors.white,
  ),
);

final lightTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'NotoNaskh',
  textTheme: TextTheme(
      // for main non-bolded text in ZikrPage.
      bodyMedium: TextStyle(
        color: Colors.black,
        fontSize: Get.put(FontController().fontSize.value),
        height: 1.8,
      ),
      // fot footer, notes
      bodySmall: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 14,
      ),
      // for numbering e.g. (12.)
      labelSmall: TextStyle(
        fontWeight: FontWeight.bold,
        // TODO: change based on theme
        color: Colors.grey.shade600,
        fontSize: 20,
      )),
  colorScheme: ColorScheme.fromSeed(
    // used for table borders
    secondaryFixed: Colors.greenAccent,
    seedColor: Colors.green,
    brightness: Brightness.light,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white30,
  ),
  iconTheme: IconThemeData(
    color: Colors.green.shade900,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      padding: WidgetStateProperty.all<EdgeInsets>(
        const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
      backgroundColor: WidgetStateProperty.all<Color>(Colors.green.shade200),
      foregroundColor: WidgetStateProperty.all<Color>(Colors.black),
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
      // side: BorderSide(color: Colors.green.shade900, width: 1),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    surfaceTintColor: Colors.green.shade900,
    iconTheme: WidgetStatePropertyAll(
      IconThemeData(
        color: Colors.green.shade900,
        // fill: 120,
      ),
    ),
    labelTextStyle: const WidgetStatePropertyAll(
      TextStyle(
        fontSize: 12,
      ),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.green[900],
    contentTextStyle:
        // TODO: why Nashk is repeated
        const TextStyle(color: Colors.white, fontFamily: 'NotoNaskh'),
    actionTextColor: Colors.white,
  ),
);

ThemeData getDarkTheme(double fontSize) {
  return ThemeData(
    useMaterial3: true,

    fontFamily: 'NotoNaskh',
    textTheme: TextTheme(
      // for main non-bolded text in ZikrPage.
      bodyMedium: TextStyle(
        // TODO: size and height should be from provider from shared_prefs, change from settings
        color: Colors.grey.shade100,
        fontSize: fontSize,
        height: 1.8,
      ),
      // fot footer and [^3], notes
      bodySmall: TextStyle(
        color: Colors.grey.shade400,
        // TODO: calc this from main fontSize
        fontSize: 14,
      ),
      // used for title in timingsScreen
      titleMedium: const TextStyle(
        fontSize: 24,
      ),
      // used for title in timingsScreen dialog
      titleSmall: const TextStyle(
        fontSize: 17,
      ),
      // for numbering e.g. (12.)
      labelSmall: TextStyle(
        fontWeight: FontWeight.bold,
        // TODO: change based on theme
        color: Colors.grey.shade400,
        // color: Colors.green,
        // TODO: calc this from main fontSize
        fontSize: 20,
      ),
    ),

    colorScheme: ColorScheme.fromSeed(
      // used for table borders
      secondaryFixed: Colors.greenAccent,
      seedColor: Colors.greenAccent,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      toolbarHeight: 60,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoNaskh',
        fontSize: 24,
        height: 2,
      ),
    ),
    iconTheme: IconThemeData(
      color: Colors.green.shade700,
    ),
    // platform: TargetPlatform.android,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        padding: WidgetStateProperty.all<EdgeInsets>(
          const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        ),
        foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
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
        // side: BorderSide(color: Colors.green.shade900, width: 1),
      ),
    ),
    // scrollbarTheme: const ScrollbarThemeData(
    //   thumbColor: MaterialStatePropertyAll(Colors.red),
    //   trackColor: MaterialStatePropertyAll(Colors.red),
    //   trackBorderColor: MaterialStatePropertyAll(Colors.red),
    //   radius: Radius.circular(10),
    //   thickness: MaterialStatePropertyAll(10),
    //   thumbVisibility: MaterialStatePropertyAll(true),
    //   trackVisibility: MaterialStatePropertyAll(true),
    //   interactive: true,
    // ),
    navigationBarTheme: NavigationBarThemeData(
      surfaceTintColor: Colors.green.shade900,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      iconTheme: const WidgetStatePropertyAll(
        IconThemeData(
          color: Colors.green,
          // fill: 120,
        ),
      ),
      labelTextStyle: const MaterialStatePropertyAll(
        TextStyle(
          fontSize: 12,
        ),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.green[900],
      contentTextStyle:
          const TextStyle(color: Colors.white, fontFamily: 'NotoNaskh'),
      actionTextColor: Colors.white,
    ),
  );
}

ThemeData getLightTheme(double fontSize) {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoNaskh',
    textTheme: TextTheme(
        // for main non-bolded text in ZikrPage.
        bodyMedium: TextStyle(
          color: Colors.black,
          fontSize: fontSize,
          height: 1.8,
        ),
        // fot footer, notes
        bodySmall: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
        // for numbering e.g. (12.)
        labelSmall: TextStyle(
          fontWeight: FontWeight.bold,
          // TODO: change based on theme
          color: Colors.grey.shade600,
          fontSize: 20,
        )),
    colorScheme: ColorScheme.fromSeed(
      // used for table borders
      secondaryFixed: Colors.greenAccent,
      seedColor: Colors.green,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white30,
    ),
    iconTheme: IconThemeData(
      color: Colors.green.shade900,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        padding: WidgetStateProperty.all<EdgeInsets>(
          const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        ),
        backgroundColor: WidgetStateProperty.all<Color>(Colors.green.shade200),
        foregroundColor: WidgetStateProperty.all<Color>(Colors.black),
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
        // side: BorderSide(color: Colors.green.shade900, width: 1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      surfaceTintColor: Colors.green.shade900,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(
          color: Colors.green.shade900,
          // fill: 120,
        ),
      ),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontSize: 12,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.green[900],
      contentTextStyle:
          const TextStyle(color: Colors.white, fontFamily: 'NotoNaskh'),
      actionTextColor: Colors.white,
    ),
  );
}
