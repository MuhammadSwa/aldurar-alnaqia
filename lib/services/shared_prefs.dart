import 'dart:async';
import 'dart:convert';

import 'package:aldurar_alnaqia/common/helpers/logger.dart';
import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart'
    show PrayerHighLatitudeRules, PrayerMadhabs, PrayerMethods, PrayerSettings;
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';
import 'package:aldurar_alnaqia/services/prayer_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized SharedPreferences keys. The native prayer-notification config
/// reads the same values, so `prayer_notification_service.dart` must use
/// these constants instead of duplicating literals.
abstract final class PrefsKeys {
  static const String latitude = 'latitude';
  static const String longitude = 'longitude';
  static const String cityInfo = 'cityInfo';
  static const String cityLabel = 'cityLabel';
  static const String method = 'method';
  static const String asrCalculation = 'asrCalculation';
  static const String highLatitudeRule = 'highLatitudeRule';
  static const String timezone = 'timezone';
  static const String bookmarks = 'bookmarks';
  static const String yousriaStartingDay = 'yousriaStartingDay';
  static const String yousriaBannerDismissed = 'yousriaBannerDismissed';
  static const String themeMode = 'theme_mode';
  static const String fontSize = 'font_size';
  static const String hijriDayOffset = 'hijri_day_offset';
  static const String fileOpenAction = 'file_open_action';
  static const String prayerForegroundEnabled = 'prayer_foreground_enabled';
  static const String prayerNativeConfig = 'prayer_native_config';
  static const String swipeHintSeen = 'swipe_hint_seen';

  static String pdfLastPage(String title) => 'pdf_last_page_$title';
}

/// Fire-and-forget write with a visible warning on failure instead of a
/// silent drop. Reads/writes through the shared_preferences mock update the
/// in-memory cache synchronously, so an immediate `get` after a `set` still
/// observes the value (existing tests rely on this).
void _persist(Future<bool> write, String what) {
  unawaited(
    write.then((ok) {
      if (!ok) logWarn('Failed to persist $what');
    }).catchError((Object e) {
      logWarn('Failed to persist $what: $e');
    }),
  );
}

// ---------------------------------------------------------------------------
// Focused stores. Each owns one unrelated preference domain and takes a
// non-nullable [SharedPreferences], so domains can be used (and tested)
// without touching the app-wide facade below.
// ---------------------------------------------------------------------------

/// Prayer/location/calculation settings.
class PrayerPrefs {
  PrayerPrefs(this._prefs);

  final SharedPreferences _prefs;

  double getLatitude() => _prefs.getDouble(PrefsKeys.latitude) ?? 0.0;

  double getLongitude() => _prefs.getDouble(PrefsKeys.longitude) ?? 0.0;

  /// The city chosen in the city picker, if any (GPS selections clear it).
  /// Coordinates themselves stay in the latitude/longitude keys.
  void setCity(City? city) {
    if (city == null) {
      _persist(_prefs.remove(PrefsKeys.cityInfo), 'city');
      return;
    }
    _persist(
      _prefs.setString(
        PrefsKeys.cityInfo,
        jsonEncode({
          'en': city.nameEn,
          'ar': city.nameAr,
          'country': city.countryCode,
        }),
      ),
      'city',
    );
  }

  City? getCity() {
    final raw = _prefs.getString(PrefsKeys.cityInfo);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final lat = getLatitude();
      final lng = getLongitude();
      if (lat == 0.0 && lng == 0.0) return null;
      return City(
        nameEn: json['en'] as String,
        nameAr: json['ar'] as String?,
        countryCode: json['country'] as String,
        latitude: lat,
        longitude: lng,
      );
    } catch (e) {
      logWarn('Failed to parse stored city info: $e — dropping corrupt key');
      _persist(_prefs.remove(PrefsKeys.cityInfo), 'corrupt city info');
      return null;
    }
  }

  /// Display label for the configured location ('القاهرة، مصر'), computed
  /// once at save time (city pick → its label; GPS → nearest city within
  /// 50 km, else coordinates) and stored as a plain string so rendering
  /// never needs the city directory. Empty when no location is configured.
  String getPrayerCityLabel() =>
      _prefs.getString(PrefsKeys.cityLabel) ?? '';

  /// Stored method or default. Absent returns the default; present-but-unknown
  /// values are logged visibly and reset to default (no silent guess).
  String getMethod() {
    final stored = _prefs.getString(PrefsKeys.method);
    if (stored == null) return PrayerMethods.egyptian;
    if (!PrayerMethods.isValid(stored)) {
      logWarn('Unknown stored prayer method "$stored" — using default');
      return PrayerMethods.egyptian;
    }
    return stored;
  }

  String getAsrCalculation() {
    final stored = _prefs.getString(PrefsKeys.asrCalculation);
    if (stored == null) return PrayerMadhabs.shafi;
    if (!PrayerMadhabs.isValid(stored)) {
      logWarn('Unknown stored madhab "$stored" — using default');
      return PrayerMadhabs.shafi;
    }
    return stored;
  }

  String getHighLatitudeRule() {
    final stored = _prefs.getString(PrefsKeys.highLatitudeRule);
    if (stored == null) return PrayerHighLatitudeRules.middleOfNight;
    if (!PrayerHighLatitudeRules.isValid(stored)) {
      logWarn('Unknown stored high-latitude rule "$stored" — using default');
      return PrayerHighLatitudeRules.middleOfNight;
    }
    return stored;
  }

  String getTimezone() => _prefs.getString(PrefsKeys.timezone) ?? '';

  /// Typed snapshot of all prayer settings. Single source of defaults and
  /// validation for the UI, the calculator, and the native bridge.
  PrayerSettings loadPrayerSettings() {
    return PrayerSettings(
      latitude: getLatitude(),
      longitude: getLongitude(),
      timezone: getTimezone(),
      method: getMethod(),
      madhab: getAsrCalculation(),
      highLatitudeRule: getHighLatitudeRule(),
    );
  }

  /// Saves interdependent prayer settings together, then refreshes the native
  /// notification once so it cannot observe a half-saved location or zone.
  Future<void> savePrayerSettings({
    required double latitude,
    required double longitude,
    required String method,
    required String asrCalculation,
    required String timezone,
    String? highLatitudeRule,
    City? city,
    String? cityLabel, // null = leave stored label unchanged
  }) async {
    await _prefs.setDouble(PrefsKeys.latitude, latitude);
    await _prefs.setDouble(PrefsKeys.longitude, longitude);
    await _prefs.setString(PrefsKeys.method, method);
    await _prefs.setString(PrefsKeys.asrCalculation, asrCalculation);
    await _prefs.setString(PrefsKeys.timezone, timezone);
    if (highLatitudeRule != null) {
      await _prefs.setString(PrefsKeys.highLatitudeRule, highLatitudeRule);
    }
    if (city == null) {
      await _prefs.remove(PrefsKeys.cityInfo);
    } else {
      await _prefs.setString(
        PrefsKeys.cityInfo,
        jsonEncode({
          'en': city.nameEn,
          'ar': city.nameAr,
          'country': city.countryCode,
        }),
      );
    }
    if (cityLabel != null) {
      await _prefs.setString(PrefsKeys.cityLabel, cityLabel);
    }
    await refreshPrayerNotification();
  }
}

/// Saved bookmarks (zikr/reading ids).
class BookmarkPrefs {
  BookmarkPrefs(this._prefs);

  final SharedPreferences _prefs;

  List<String> getBookmarks() =>
      _prefs.getStringList(PrefsKeys.bookmarks) ?? [];

  void setBookmarks(List<String> bookmarks) {
    _persist(
      _prefs.setStringList(PrefsKeys.bookmarks, bookmarks),
      'bookmarks',
    );
  }

  void removeAllBookmarks() {
    _persist(_prefs.remove(PrefsKeys.bookmarks), 'bookmarks');
  }

  void addBookmark(String bookmark) {
    final bookmarks = getBookmarks();
    if (bookmarks.contains(bookmark)) return;
    bookmarks.add(bookmark);
    setBookmarks(bookmarks);
  }

  void removeBookmark(String bookmark) {
    final bookmarks = getBookmarks();
    if (!bookmarks.remove(bookmark)) return;
    setBookmarks(bookmarks);
  }
}

/// Yousria cycle state.
class YousriaPrefs {
  YousriaPrefs(this._prefs);

  final SharedPreferences _prefs;

  void setBeginning(DateTime startingDay) {
    // NOTE: set to midnight of the beginning day
    // so when subtract it, hours and minutes wouldn't be considered
    final dayMidnight =
        DateTime(startingDay.year, startingDay.month, startingDay.day);
    _persist(
      _prefs.setString(
        PrefsKeys.yousriaStartingDay,
        dayMidnight.toIso8601String(),
      ),
      'yousria beginning',
    );
  }

  /// No stored beginning — default to today's midnight and persist it.
  /// Single `now` so the returned and stored values agree.
  /// Corrupt values are dropped (key removed) and reset to today visibly.
  DateTime getBeginning() {
    final stored = _prefs.getString(PrefsKeys.yousriaStartingDay);
    if (stored != null) {
      try {
        return DateTime.parse(stored);
      } catch (e) {
        logWarn(
          'Failed to parse yousria beginning "$stored": $e — resetting to today',
        );
        _persist(
          _prefs.remove(PrefsKeys.yousriaStartingDay),
          'corrupt yousria beginning',
        );
      }
    }
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    _persist(
      _prefs.setString(
        PrefsKeys.yousriaStartingDay,
        todayMidnight.toIso8601String(),
      ),
      'yousria beginning',
    );
    return todayMidnight;
  }

  bool getBannerDismissed() =>
      _prefs.getBool(PrefsKeys.yousriaBannerDismissed) ?? false;

  Future<void> setBannerDismissed(bool dismissed) async {
    final ok = await _prefs.setBool(
      PrefsKeys.yousriaBannerDismissed,
      dismissed,
    );
    if (!ok) logWarn('Failed to persist yousria banner flag');
  }
}

/// Appearance and reading preferences.
class AppearancePrefs {
  AppearancePrefs(this._prefs);

  final SharedPreferences _prefs;

  /// Single source of truth for the body font-size setting.
  /// `AppTheme.defaultFontSize` aliases [defaultFontSize] so the theme
  /// default cannot drift from the stored-prefs default.
  static const double defaultFontSize = 22;
  static const double minFontSize = 16;
  static const double maxFontSize = 40;

  /// Raw stored value. Kept string-based so this service does not depend
  /// on Flutter material; providers map it to [ThemeMode].
  /// Absent returns system; unknown values are logged and reset to system.
  String getThemeMode() {
    final stored = _prefs.getString(PrefsKeys.themeMode);
    if (stored == null) return 'system';
    if (stored != 'light' && stored != 'dark' && stored != 'system') {
      logWarn('Unknown stored theme mode "$stored" — using system');
      return 'system';
    }
    return stored;
  }

  Future<void> setThemeMode(String mode) async {
    final ok = await _prefs.setString(PrefsKeys.themeMode, mode);
    if (!ok) logWarn('Failed to persist theme mode "$mode"');
  }

  void setFontSize(double size) {
    _persist(_prefs.setDouble(PrefsKeys.fontSize, size), 'font size $size');
  }

  double getFontSize() {
    final stored = _prefs.getDouble(PrefsKeys.fontSize);
    if (stored != null &&
        stored.isFinite &&
        stored >= minFontSize &&
        stored <= maxFontSize) {
      return stored;
    }
    if (stored != null) {
      logWarn('Invalid stored font size "$stored" — using default');
    }
    return defaultFontSize;
  }

  void setHijriDayOffset(int offset) {
    _persist(
      _prefs.setInt(PrefsKeys.hijriDayOffset, offset),
      'hijri offset $offset',
    );
    unawaited(refreshPrayerNotification());
  }

  int getHijriDayOffset() {
    final stored = _prefs.getInt(PrefsKeys.hijriDayOffset);
    if (stored == null) return 0;
    if (stored < -2 || stored > 2) {
      logWarn('Invalid stored hijri offset "$stored" — using 0');
      return 0;
    }
    return stored;
  }

  // --- File open action preference: 'ask' | 'open' | 'download' ---
  // Single preference shared by audio and books for non-downloaded files.
  // Unknown values are logged and reset to ask (no silent guess).
  String getFileOpenAction() {
    final stored = _prefs.getString(PrefsKeys.fileOpenAction);
    if (stored == null) return 'ask';
    if (stored != 'ask' && stored != 'open' && stored != 'download') {
      logWarn('Unknown stored file open action "$stored" — using ask');
      return 'ask';
    }
    return stored;
  }

  Future<void> setFileOpenAction(String action) async {
    final ok = await _prefs.setString(PrefsKeys.fileOpenAction, action);
    if (!ok) logWarn('Failed to persist file open action "$action"');
  }

  /// First-run swipe hint for slidable zikr collections. False until the
  /// user has seen/dismissed the hand-slide onboarding once.
  bool getSwipeHintSeen() =>
      _prefs.getBool(PrefsKeys.swipeHintSeen) ?? false;

  Future<void> setSwipeHintSeen(bool seen) async {
    final ok = await _prefs.setBool(PrefsKeys.swipeHintSeen, seen);
    if (!ok) logWarn('Failed to persist swipe hint flag');
  }
}

/// Per-book PDF reading positions.
class PdfPrefs {
  PdfPrefs(this._prefs);

  final SharedPreferences _prefs;

  Future<void> setLastPage(String title, int page) async {
    final ok = await _prefs.setInt(PrefsKeys.pdfLastPage(title), page);
    if (!ok) logWarn('Failed to persist PDF page for "$title"');
  }

  int? getLastPage(String title) =>
      _prefs.getInt(PrefsKeys.pdfLastPage(title));
}

// ---------------------------------------------------------------------------
// App-wide facade. Kept for the existing call sites (see blast-radius note);
// new code should prefer `SharedPreferencesService.instance.<domain>`.
// Every accessor goes through [_prefs], which throws a [StateError] before
// init instead of silently returning defaults or dropping writes.
// ---------------------------------------------------------------------------

class SharedPreferencesService {
  /// Historical throwaway-constructible entry point (`().init()` in main and
  /// existing tests). The constructed object holds no state; [init] populates
  /// the static holder. New code should call [ensureInitialized] directly.
  SharedPreferencesService();

  /// Preferred entry point for new code: `await SharedPreferencesService.init()`
  /// once in `main()` before `runApp`, then `SharedPreferencesService.instance`
  /// (or the static shims below during migration).
  SharedPreferencesService._(SharedPreferences prefs)
      : prayer = PrayerPrefs(prefs),
        bookmarks = BookmarkPrefs(prefs),
        yousria = YousriaPrefs(prefs),
        appearance = AppearancePrefs(prefs),
        pdf = PdfPrefs(prefs);

  late final PrayerPrefs prayer;
  late final BookmarkPrefs bookmarks;
  late final YousriaPrefs yousria;
  late final AppearancePrefs appearance;
  late final PdfPrefs pdf;

  static SharedPreferencesService? _instance;

  /// True once [init]/[ensureInitialized] has completed.
  static bool get isInitialized => _instance != null;

  /// Fail-fast accessor: throws [StateError] when used before init.
  static SharedPreferencesService get instance {
    final current = _instance;
    if (current == null) {
      throw StateError(
        'SharedPreferencesService.init() must be awaited before use '
        '(call it in main() before runApp).',
      );
    }
    return current;
  }

  static SharedPreferencesService _require() => instance;

  /// Idempotent async initializer. Safe to call more than once.
  static Future<void> ensureInitialized() async {
    if (_instance != null) return;
    final prefs = await SharedPreferences.getInstance();
    _instance = SharedPreferencesService._(prefs);
  }

  /// Historical entry point (`SharedPreferencesService().init()` in main and
  /// tests). Always re-reads the backing store so tests that reset the mock
  /// (`setMockInitialValues` + `init()`) observe fresh values; new code
  /// should call [ensureInitialized] directly.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _instance = SharedPreferencesService._(prefs);
  }

  /// Preferred static initializer for new code.
  static Future<void> initStatic() => ensureInitialized();

  @visibleForTesting
  static void resetForTest() {
    _instance = null;
  }

  // --- Prayer shims (delegate to [PrayerPrefs]) ---

  static double getLatitude() => _require().prayer.getLatitude();

  static double getLongitude() => _require().prayer.getLongitude();

  static void setCity(City? city) => _require().prayer.setCity(city);

  static City? getCity() => _require().prayer.getCity();

  static String getPrayerCityLabel() =>
      _require().prayer.getPrayerCityLabel();

  static String getMethod() => _require().prayer.getMethod();

  static String getAsrCalculation() => _require().prayer.getAsrCalculation();

  static String getHighLatitudeRule() =>
      _require().prayer.getHighLatitudeRule();

  static String getTimezone() => _require().prayer.getTimezone();

  static PrayerSettings loadPrayerSettings() =>
      _require().prayer.loadPrayerSettings();

  static Future<void> savePrayerSettings({
    required double latitude,
    required double longitude,
    required String method,
    required String asrCalculation,
    required String timezone,
    String? highLatitudeRule,
    City? city,
    String? cityLabel,
  }) =>
      _require().prayer.savePrayerSettings(
        latitude: latitude,
        longitude: longitude,
        method: method,
        asrCalculation: asrCalculation,
        timezone: timezone,
        highLatitudeRule: highLatitudeRule,
        city: city,
        cityLabel: cityLabel,
      );

  // --- Bookmark shims ---

  static List<String> getBookmarks() => _require().bookmarks.getBookmarks();

  static void setBookmarks(List<String> bookmarks) =>
      _require().bookmarks.setBookmarks(bookmarks);

  static void removeAllBookmarks() =>
      _require().bookmarks.removeAllBookmarks();

  static void addBookmark(String bookmark) =>
      _require().bookmarks.addBookmark(bookmark);

  static void removeBookmark(String bookmark) =>
      _require().bookmarks.removeBookmark(bookmark);

  // --- Yousria shims ---

  static void setYousriaBeginning(DateTime startingDay) =>
      _require().yousria.setBeginning(startingDay);

  static DateTime getYousriaBeginning() =>
      _require().yousria.getBeginning();

  static bool getYousriaBannerDismissed() =>
      _require().yousria.getBannerDismissed();

  static Future<void> setYousriaBannerDismissed(bool dismissed) =>
      _require().yousria.setBannerDismissed(dismissed);

  // --- Appearance shims ---

  static String getThemeMode() => _require().appearance.getThemeMode();

  static Future<void> setThemeMode(String mode) =>
      _require().appearance.setThemeMode(mode);

  static void setFontSize(double size) =>
      _require().appearance.setFontSize(size);

  static double getFontSize() => _require().appearance.getFontSize();

  static void setHijriDayOffset(int offset) =>
      _require().appearance.setHijriDayOffset(offset);

  static int getHijriDayOffset() => _require().appearance.getHijriDayOffset();

  static String getFileOpenAction() =>
      _require().appearance.getFileOpenAction();

  static Future<void> setFileOpenAction(String action) =>
      _require().appearance.setFileOpenAction(action);

  static bool getSwipeHintSeen() =>
      _require().appearance.getSwipeHintSeen();

  static Future<void> setSwipeHintSeen(bool seen) =>
      _require().appearance.setSwipeHintSeen(seen);

  // --- PDF shims ---

  static Future<void> setPdfLastPage(String bookId, int page) =>
      _require().pdf.setLastPage(bookId, page);

  static int? getPdfLastPage(String bookId) =>
      _require().pdf.getLastPage(bookId);
}
