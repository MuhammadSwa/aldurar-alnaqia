// city_directory.dart
//
// Offline, in-memory directory of ~34k world cities used by the prayer
// timings city picker.
//
// Loading: the JSON asset (~2.3 MB raw) is parsed once and cached for the
// lifetime of the app. Search is a single linear scan: entries are rejected
// with one cheap substring check each, and exact/prefix/word-start tiering
// runs only on the few entries that contain the query (~9 ms for the reject
// scan vs ~40 ms before, measured on desktop; phones are slower). The UI
// additionally debounces keystrokes and fetches results + total count in
// one pass via [searchWithCount].

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aldurar_alnaqia/common/helpers/arabic.dart'
    show normalizeArabic;
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

  /// Search index, built eagerly in the constructor so the provider's
  /// loading state (and its spinner) covers both JSON parsing and indexing.
  /// Previously this was `late final`, which deferred ~170 ms of normalize
  /// work to the first keystroke, with no loading indicator visible.
  final List<_IndexedCity> _index;

  CityDirectory({required this.cities, required this.countries})
      : _index = [
          for (var i = 0; i < cities.length; i++)
            _IndexedCity(cities[i], i, countries[cities[i].countryCode]),
        ];

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
  ///
  /// Delegates to the shared [normalizeArabic] helper so the city picker
  /// and the global search stay consistent.
  static String normalize(String input) => normalizeArabic(input);

  /// Searches Arabic and English city AND country names. Tiers (best first):
  /// city exact (100) > country exact (90) > city prefix (80) >
  /// country prefix (70) > city word-start (60) > country word-start (50) >
  /// city substring (40) > country substring (30),
  /// with a small population bonus inside each tier. Typing a country name
  /// (e.g. 'مصر' or 'Egypt') therefore lists that country's cities.
  /// Returns at most [limit] matches, best first. Empty/blank query returns [].
  /// Prefer [searchWithCount] when the total match count is also needed: it
  /// produces both in a single pass over the index.
  List<City> search(String query, {int limit = 60}) {
    return searchWithCount(query, limit: limit).results;
  }

  /// Single-pass search: ranked results (at most [limit]) plus the total
  /// number of matches, for 'X results' hints. Empty/blank query returns
  /// no results and a zero total.
  ({List<City> results, int total}) searchWithCount(
    String query, {
    int limit = 60,
  }) {
    final q = normalize(query);
    if (q.isEmpty) return (results: const [], total: 0);
    final scored = _scoreAll(q);
    scored.sort((a, b) => b.score.compareTo(a.score));
    final count = scored.length < limit ? scored.length : limit;
    return (
      results: [for (var i = 0; i < count; i++) scored[i].city],
      total: scored.length,
    );
  }

  /// Scores every entry matching [q] (already normalized, non-empty),
  /// in index order (unsorted). Shared by [searchWithCount] and
  /// [countMatches] so the UI never scans the directory twice per keystroke.
  List<({City city, int score})> _scoreAll(String q) {
    final total = _index.length;
    final scored = <({City city, int score})>[];
    for (final entry in _index) {
      // Cheap reject first: one substring scan per name, no allocations.
      // Exact/prefix/word-start tiering runs only for entries containing
      // the query — a tiny fraction of the directory for normal queries.
      final cityHit = entry.normAr.contains(q) || entry.normEn.contains(q);
      final countryHit = entry.normCountryAr.contains(q) ||
          entry.normCountryEn.contains(q);
      if (!cityHit && !countryHit) continue;
      final cityTier = cityHit ? _matchTier(entry.normAr, entry.normEn, q) : 0;
      final countryTier = countryHit
          ? _matchTier(entry.normCountryAr, entry.normCountryEn, q)
          : 0;
      // Country hits rank one step below the equivalent city hit so a
      // city-name match always outranks a country-name match.
      var tier = cityTier;
      final countryScore = countryTier > 0 ? countryTier - 10 : 0;
      if (countryScore > tier) tier = countryScore;
      // Unreachable: a contains-hit always tiers >= 40. Kept as a guard.
      if (tier == 0) continue;
      // 0..9 bonus: earlier (more populous) cities rank higher in-tier.
      final popularity = ((total - entry.order) / total * 9).round();
      scored.add((city: entry.city, score: tier + popularity));
    }
    return scored;
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
  /// Includes country-name matches, mirroring [searchWithCount]; a query
  /// with a contains-hit always tiers above zero, so both agree exactly.
  int countMatches(String query) {
    final q = normalize(query);
    if (q.isEmpty) return 0;
    return _scoreAll(q).length;
  }

  /// True when [q] matches the start of any whitespace-separated word.
  /// Allocation-free: scans [text] with [indexOf] instead of building
  /// padded copies (`(' $text ').contains(' $q')`) per entry per keystroke.
  static bool _wordStarts(String text, String q) {
    if (q.length > text.length) return false;
    if (text.startsWith(q)) return true;
    var i = text.indexOf(q, 1);
    while (i != -1) {
      if (text.codeUnitAt(i - 1) == 0x20) return true;
      i = text.indexOf(q, i + 1);
    }
    return false;
  }
}

/// Shared, lazily-loaded city directory (parsed once per app lifetime).
final cityDirectoryProvider = FutureProvider<CityDirectory>((ref) async {
  return CityDirectory.load();
});
