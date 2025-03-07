import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static final SharedPreferencesService _instance =
      SharedPreferencesService._instance;
  static SharedPreferences? _sharedPreferences;

  // SharedPreferencesService._internal();

  Future<void> init() async {
    _sharedPreferences = await SharedPreferences.getInstance();
  }

  static double getLatitude() {
    return _sharedPreferences!.getDouble('latitude') ?? 0.0;
  }

  static double getLongitude() {
    return _sharedPreferences!.getDouble('longitude') ?? 0.0;
  }

  static void setLatitude(double lat) {
    _sharedPreferences!.setDouble('latitude', lat);
  }

  static void setLongitude(double long) {
    _sharedPreferences!.setDouble('longitude', long);
  }

  static void setMethod(String method) {
    _sharedPreferences!.setString('method', method);
  }

  static String getMethod() {
    return _sharedPreferences!.getString('method') ?? 'egyptian';
  }

  static void setAsrCalculation(String asrCalculation) {
    _sharedPreferences!.setString('asrCalculation', asrCalculation);
  }

  static String getAsrCalculation() {
    return _sharedPreferences!.getString('asrCalculation') ?? 'shafi';
  }

  // add bookmark to the list,
  // remove bookmarks  from the list
  // remove all bookmarks.
  static List<String> getBookmarks() {
    return _sharedPreferences!.getStringList('bookmarks') ?? [];
  }

  static void setBookmarks(List<String> bookmarks) {
    _sharedPreferences!.setStringList('bookmarks', bookmarks);
  }

  static void removeAllBookmarks() {
    _sharedPreferences!.remove('bookmarks');
  }

  static void addBookmark(String bookmark) {
    List<String> bookmarks = getBookmarks();
    bookmarks.add(bookmark);
    setBookmarks(bookmarks);
  }

  static void removeBookmark(String bookmark) {
    List<String> bookmarks = getBookmarks();
    bookmarks.remove(bookmark);
    setBookmarks(bookmarks);
  }

  static void setYousriaBeginning(DateTime startingDay) {
    // NOTE: set to midnight of the beginning day
    // so when subtract it, hours and minutes wouldn't be considered
    final dayMidnight =
        DateTime(startingDay.year, startingDay.month, startingDay.day);
    // return todaysMidnight;
    _sharedPreferences!
        .setString('yousriaStartingDay', dayMidnight.toIso8601String());
  }

  static DateTime getYousriaBeginning() {
    final startingDay = _sharedPreferences!.getString('yousriaStartingDay');
    if (startingDay == null) {
      // if startingDay isn't setup(e.g. first time installying the app, it's automatically sets today as the beginning day
      // use then can change it in settings.
      SharedPreferencesService.setYousriaBeginning(DateTime.now());
      return DateTime.now();
    }

    return DateTime.parse(startingDay);
  }

  static void setFontSize(double size) {
    _sharedPreferences!.setDouble('font_size', size);
  }

  static double getFontSize() {
    final size = _sharedPreferences!.getDouble('font_size');
    if (size == null) {
      return 20;
    }
    return size;
  }

  static void setQuranFontFamily(String fontFamily) {
    _sharedPreferences!.setString('quran_font_family', fontFamily);
  }

  static String getQuranFontFamily() {
    return _sharedPreferences!.getString('quran_font_family') ?? 'AmiriQuran';
  }

  static void setHijriDayOffset(int offset) {
    print('setting offest to $offset');
    _sharedPreferences!.setInt('hijri_day_offset', offset);
  }

  static int getHijriDayOffset() {
    final offset = _sharedPreferences!.getInt('hijri_day_offset');
    if (offset == null) {
      return 0;
    }
    return offset;
  }
}
