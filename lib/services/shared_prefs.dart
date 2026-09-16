import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:aldurar_alnaqia/common/helpers/logger.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/prayer_schedule.dart'
    show PrayerSettings;
import 'package:aldurar_alnaqia/services/prayer_notification_service.dart';

/// Centralized SharedPreferences keys. The native prayer-notification config
/// reads the same values, so `prayer_notification_service.dart` must use
/// these constants instead of duplicating literals.
abstract final class PrefsKeys {
  static const String latitude = 'latitude';
  static const String longitude = 'longitude';
  static const String cityName = 'cityName';
  static const String cityInfo = 'cityInfo';
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
  static const String prayerPreciseAlerts = 'prayer_precise_alerts';

  static String pdfLastPage(String title) => 'pdf_last_page_$title';
}

class SharedPreferencesService {
  static final SharedPreferencesService _instance =
      SharedPreferencesService._instance;
  static SharedPreferences? _sharedPreferences;

  Future<void> init() async {
    _sharedPreferences = await SharedPreferences.getInstance();
  }

  static double getLatitude() {
    return _sharedPreferences?.getDouble(PrefsKeys.latitude) ?? 0.0;
  }

  static double getLongitude() {
    return _sharedPreferences?.getDouble(PrefsKeys.longitude) ?? 0.0;
  }

  static String getCityName() {
    return _sharedPreferences?.getString(PrefsKeys.cityName) ?? '';
  }

  static void setCityName(String cityName) {
    _sharedPreferences?.setString(PrefsKeys.cityName, cityName);
  }

  /// The city chosen in the city picker, if any (GPS selections clear it).
  /// Coordinates themselves stay in the latitude/longitude keys.
  static void setCity(City? city) {
    if (city == null) {
      _sharedPreferences?.remove(PrefsKeys.cityInfo);
      setCityName('');
      return;
    }
    _sharedPreferences?.setString(
      PrefsKeys.cityInfo,
      jsonEncode({
        'en': city.nameEn,
        'ar': city.nameAr,
        'country': city.countryCode,
      }),
    );
    setCityName(city.displayName);
  }

  static City? getCity() {
    final raw = _sharedPreferences?.getString(PrefsKeys.cityInfo);
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
      logWarn('Failed to parse stored city info: $e');
      return null;
    }
  }

  static String getMethod() {
    return _sharedPreferences?.getString(PrefsKeys.method) ?? 'egyptian';
  }

  static String getAsrCalculation() {
    return _sharedPreferences?.getString(PrefsKeys.asrCalculation) ?? 'shafi';
  }

  static String getHighLatitudeRule() {
    return _sharedPreferences?.getString(PrefsKeys.highLatitudeRule) ??
        'middle_of_night';
  }

  static String getTimezone() {
    return _sharedPreferences?.getString(PrefsKeys.timezone) ?? '';
  }

  /// Whether prayer-arrival alerts may wake the device with an exact alarm.
  /// Defaults to true (previous behavior). When false, the native service
  /// uses inexact wakeups for all boundaries — cheaper in Doze, but arrival
  /// alerts can arrive minutes late.
  static bool getPrayerPreciseAlerts() {
    return _sharedPreferences?.getBool(PrefsKeys.prayerPreciseAlerts) ?? true;
  }

  static Future<void> setPrayerPreciseAlerts(bool value) async {
    await _sharedPreferences?.setBool(PrefsKeys.prayerPreciseAlerts, value);
    await refreshPrayerNotification();
  }

  /// Typed snapshot of all prayer settings. Single source of defaults and
  /// validation for the UI, the calculator, and the native bridge.
  static PrayerSettings loadPrayerSettings() {
    return PrayerSettings(
      latitude: getLatitude(),
      longitude: getLongitude(),
      timezone: getTimezone(),
      method: getMethod(),
      madhab: getAsrCalculation(),
      highLatitudeRule: getHighLatitudeRule(),
      hijriOffset: getHijriDayOffset(),
    );
  }

  /// Saves interdependent prayer settings together, then refreshes the native
  /// notification once so it cannot observe a half-saved location or zone.
  static Future<void> savePrayerSettings({
    required double latitude,
    required double longitude,
    required String method,
    required String asrCalculation,
    required String timezone,
    String? highLatitudeRule,
    City? city,
  }) async {
    final prefs = _sharedPreferences;
    if (prefs == null) return;

    await prefs.setDouble(PrefsKeys.latitude, latitude);
    await prefs.setDouble(PrefsKeys.longitude, longitude);
    await prefs.setString(PrefsKeys.method, method);
    await prefs.setString(PrefsKeys.asrCalculation, asrCalculation);
    await prefs.setString(PrefsKeys.timezone, timezone);
    if (highLatitudeRule != null) {
      await prefs.setString(PrefsKeys.highLatitudeRule, highLatitudeRule);
    }
    if (city == null) {
      await prefs.remove(PrefsKeys.cityInfo);
      await prefs.remove(PrefsKeys.cityName);
    } else {
      await prefs.setString(
        PrefsKeys.cityInfo,
        jsonEncode({
          'en': city.nameEn,
          'ar': city.nameAr,
          'country': city.countryCode,
        }),
      );
      await prefs.setString(PrefsKeys.cityName, city.displayName);
    }
    await refreshPrayerNotification();
  }

  static List<String> getBookmarks() {
    return _sharedPreferences?.getStringList(PrefsKeys.bookmarks) ?? [];
  }

  static void setBookmarks(List<String> bookmarks) {
    _sharedPreferences?.setStringList(PrefsKeys.bookmarks, bookmarks);
  }

  static void removeAllBookmarks() {
    _sharedPreferences?.remove(PrefsKeys.bookmarks);
  }

  static void addBookmark(String bookmark) {
    final bookmarks = getBookmarks();
    if (bookmarks.contains(bookmark)) return;
    bookmarks.add(bookmark);
    setBookmarks(bookmarks);
  }

  static void removeBookmark(String bookmark) {
    final bookmarks = getBookmarks();
    if (!bookmarks.remove(bookmark)) return;
    setBookmarks(bookmarks);
  }

  static void setYousriaBeginning(DateTime startingDay) {
    // NOTE: set to midnight of the beginning day
    // so when subtract it, hours and minutes wouldn't be considered
    final dayMidnight =
        DateTime(startingDay.year, startingDay.month, startingDay.day);
    _sharedPreferences?.setString(
      PrefsKeys.yousriaStartingDay,
      dayMidnight.toIso8601String(),
    );
  }

  /// First launch has no stored beginning — default to today's midnight and
  /// persist it. Single `now` so the returned and stored values agree.
  static DateTime getYousriaBeginning() {
    final stored = _sharedPreferences?.getString(PrefsKeys.yousriaStartingDay);
    if (stored != null) {
      try {
        return DateTime.parse(stored);
      } catch (e) {
        logWarn('Failed to parse yousria beginning "$stored": $e');
      }
    }
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    _sharedPreferences?.setString(
      PrefsKeys.yousriaStartingDay,
      todayMidnight.toIso8601String(),
    );
    return todayMidnight;
  }

  static bool getYousriaBannerDismissed() {
    return _sharedPreferences?.getBool(PrefsKeys.yousriaBannerDismissed) ??
        false;
  }

  static Future<void> setYousriaBannerDismissed(bool dismissed) async {
    await _sharedPreferences?.setBool(
      PrefsKeys.yousriaBannerDismissed,
      dismissed,
    );
  }

  // --- Theme mode preference: 'light' | 'dark' | 'system' ---

  /// Raw stored value. Kept string-based so this service does not depend
  /// on Flutter material; providers map it to [ThemeMode].
  static String getThemeMode() {
    return _sharedPreferences?.getString(PrefsKeys.themeMode) ?? 'system';
  }

  static Future<void> setThemeMode(String mode) async {
    await _sharedPreferences?.setString(PrefsKeys.themeMode, mode);
  }

  static void setFontSize(double size) {
    _sharedPreferences?.setDouble(PrefsKeys.fontSize, size);
  }

  static double getFontSize() {
    return _sharedPreferences?.getDouble(PrefsKeys.fontSize) ?? 22;
  }

  static void setHijriDayOffset(int offset) {
    _sharedPreferences?.setInt(PrefsKeys.hijriDayOffset, offset);
    unawaited(refreshPrayerNotification());
  }

  static int getHijriDayOffset() {
    return _sharedPreferences?.getInt(PrefsKeys.hijriDayOffset) ?? 0;
  }

  // --- PDF last page persistence ---
  static Future<void> setPdfLastPage(String title, int page) async {
    await _sharedPreferences?.setInt(PrefsKeys.pdfLastPage(title), page);
  }

  static int? getPdfLastPage(String title) {
    return _sharedPreferences?.getInt(PrefsKeys.pdfLastPage(title));
  }

  // --- File open action preference: 'ask' | 'open' | 'download' ---
  // Single preference shared by audio and books for non-downloaded files.
  static String getFileOpenAction() {
    return _sharedPreferences?.getString(PrefsKeys.fileOpenAction) ?? 'ask';
  }

  static Future<void> setFileOpenAction(String action) async {
    await _sharedPreferences?.setString(PrefsKeys.fileOpenAction, action);
  }
}
