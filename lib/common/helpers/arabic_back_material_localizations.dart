import 'package:flutter/material.dart';

/// Overrides only the automatic AppBar back-button long-press tooltip.
///
/// The app is Arabic-first but intentionally does not pull in the full
/// `flutter_localizations` package; without it, [DefaultMaterialLocalizations]
/// supplies the English "Back". Subclassing it lets us keep every default
/// English string and replace just this one with "رجوع".
///
/// Registered first in `MaterialApp.localizationsDelegates` in `main.dart`
/// (first delegate wins for a given [MaterialLocalizations] type).
class ArabicBackMaterialLocalizations extends DefaultMaterialLocalizations {
  const ArabicBackMaterialLocalizations();

  @override
  String get backButtonTooltip => 'رجوع';
}

class ArabicBackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const ArabicBackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      Future.value(const ArabicBackMaterialLocalizations());

  @override
  bool shouldReload(ArabicBackMaterialLocalizationsDelegate old) => false;
}
