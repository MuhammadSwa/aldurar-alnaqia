/// Shared Arabic/Latin normalization for search.
///
/// Extracted from `CityDirectory.normalize` (the richer variant) so
/// `SearchWidget` and the city picker share one implementation instead of
/// two divergent `replaceAll` chains.
final RegExp _arabicDiacritics =
    RegExp(r'[\u064B-\u0652\u0670\u0640\u200C\u200D]');
final RegExp _arabicHamzaVariants = RegExp('[أإآٱ]');
final RegExp _arabicWhitespace = RegExp(r'\s+');

String normalizeArabic(String input) {
  final out = input
      .replaceAll(_arabicDiacritics, '')
      .replaceAll(_arabicHamzaVariants, 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .toLowerCase();
  return out.replaceAll(_arabicWhitespace, ' ').trim();
}
