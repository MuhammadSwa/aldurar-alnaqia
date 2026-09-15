// city_directory.dart
//
// Offline, in-memory directory of ~34k world cities used by the prayer
// timings city picker.
//
// Loading: the JSON asset (~2.3 MB raw) is parsed once and cached for the
// lifetime of the app. Search itself is a single linear scan with cheap
// string matching, so no isolate is needed (a scan over 34k short strings
// takes a few milliseconds); the UI additionally debounces keystrokes.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';

/// Precomputed normalized search forms for one city.
class _IndexedCity {
  final City city;

  /// Population rank proxy: lower index == larger city (asset is sorted by
  /// population descending). Used as a tiebreaker so well-known cities
  /// surface first.
  final int order;
  final String normAr;
  final String normEn;
  final String normCountryAr;
  final String normCountryEn;

  _IndexedCity(this.city, this.order, CountryInfo? country)
      : normAr = CityDirectory.normalize(city.nameAr ?? ''),
        normEn = CityDirectory.normalize(city.nameEn),
        normCountryAr = CityDirectory.normalize(country?.nameAr ?? ''),
        normCountryEn = CityDirectory.normalize(country?.nameEn ?? '');
}

class CityDirectory {
  final List<City> cities;
  final Map<String, CountryInfo> countries;
  late final List<_IndexedCity> _index = [
    for (var i = 0; i < cities.length; i++)
      _IndexedCity(cities[i], i, countries[cities[i].countryCode]),
  ];

  CityDirectory({required this.cities, required this.countries});

  factory CityDirectory.fromJson(Map<String, dynamic> json) {
    final countriesJson = json['countries'] as Map<String, dynamic>;
    return CityDirectory(
      cities: [
        for (final c in json['cities'] as List) City.fromJson(c),
      ],
      countries: {
        for (final e in countriesJson.entries)
          e.key: CountryInfo.fromJson(e.key, e.value),
      },
    );
  }

  /// Loads and parses the bundled asset. The caller is expected to cache
  /// the result (see [cityDirectoryProvider]).
  static Future<CityDirectory> load() async {
    final raw = await rootBundle.loadString('assets/data/cities.json');
    return CityDirectory.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Country name for the Arabic UI (Arabic, English fallback, code last).
  String countryLabel(String code) {
    final info = countries[code];
    if (info == null) return code;
    return info.displayName;
  }

  /// 'City، Country' label, e.g. 'القاهرة، مصر'.
  String cityLabel(City city) =>
      '${city.displayName}، ${countryLabel(city.countryCode)}';

  /// Normalizes Arabic + Latin text so spelling variants match:
  /// diacritics/tatweel removed, أإآٱ→ا, ؤ→و, ئ→ي, ة→ه, ى→ي,
  /// lowercased, whitespace collapsed.
  static String normalize(String input) {
    var out = input
        .replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640\u200C\u200D]'), '')
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .toLowerCase();
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out;
  }

  /// Searches Arabic and English city AND country names. Tiers (best first):
  /// city exact (100) > country exact (90) > city prefix (80) >
  /// country prefix (70) > city word-start (60) > country word-start (50) >
  /// city substring (40) > country substring (30),
  /// with a small population bonus inside each tier. Typing a country name
  /// (e.g. 'مصر' or 'Egypt') therefore lists that country's cities.
  /// Returns at most [limit] matches, best first. Empty/blank query returns [].
  List<City> search(String query, {int limit = 60}) {
    final q = normalize(query);
    if (q.isEmpty) return const [];

    final total = _index.length;
    final scored = <({City city, int score})>[];
    for (final entry in _index) {
      final cityTier = _matchTier(entry.normAr, entry.normEn, q);
      final countryTier = _matchTier(
        entry.normCountryAr,
        entry.normCountryEn,
        q,
      );
      // Country hits rank one step below the equivalent city hit so a
      // city-name match always outranks a country-name match.
      var tier = cityTier;
      final countryScore = countryTier > 0 ? countryTier - 10 : 0;
      if (countryScore > tier) tier = countryScore;
      if (tier == 0) continue;
      // 0..9 bonus: earlier (more populous) cities rank higher in-tier.
      final popularity = ((total - entry.order) / total * 9).round();
      scored.add((city: entry.city, score: tier + popularity));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final count = scored.length < limit ? scored.length : limit;
    return [for (var i = 0; i < count; i++) scored[i].city];
  }

  /// Tier for a (arabic, english) name pair: exact 100 > prefix 80 >
  /// word-start 60 > substring 40, else 0.
  static int _matchTier(String normAr, String normEn, String q) {
    if (q.isEmpty) return 0;
    if ((normAr.isNotEmpty && normAr == q) || normEn == q) return 100;
    if ((normAr.isNotEmpty && normAr.startsWith(q)) ||
        normEn.startsWith(q)) {
      return 80;
    }
    if ((normAr.isNotEmpty && _wordStarts(normAr, q)) ||
        _wordStarts(normEn, q)) {
      return 60;
    }
    if ((normAr.isNotEmpty && normAr.contains(q)) || normEn.contains(q)) {
      return 40;
    }
    return 0;
  }

  /// Counts matches without building the ranking (for 'X results' hints).
  /// Includes country-name matches, mirroring [search].
  int countMatches(String query) {
    final q = normalize(query);
    if (q.isEmpty) return 0;
    var count = 0;
    for (final entry in _index) {
      if (entry.normAr.contains(q) ||
          entry.normEn.contains(q) ||
          (entry.normCountryAr.isNotEmpty &&
              entry.normCountryAr.contains(q)) ||
          entry.normCountryEn.contains(q)) {
        count++;
      }
    }
    return count;
  }

  /// True when [q] matches the start of any whitespace-separated word.
  static bool _wordStarts(String text, String q) {
    if (text.startsWith(q)) return true;
    return (' $text ').contains(' $q');
  }
}

/// Shared, lazily-loaded city directory (parsed once per app lifetime).
final cityDirectoryProvider = FutureProvider<CityDirectory>((ref) async {
  return CityDirectory.load();
});
