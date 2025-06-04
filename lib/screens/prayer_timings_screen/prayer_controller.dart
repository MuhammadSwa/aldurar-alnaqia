// controllers/prayer_controller.dart
import 'dart:async';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/next_prayer_info.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/prayer_settings.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/prayer_timeData.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_service.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:get/get.dart';
import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';

class PrayerController extends GetxController {
  // Reactive variables
  final _prayerSettings = Rx<PrayerSettings?>(null);
  final _prayerTimes = Rx<PrayerTimes?>(null);
  final _nextPrayerInfo = Rx<NextPrayerInfo?>(null);
  final _hijriOffset = 0.obs;
  final _currentTime = DateTime.now().obs;

  // Timer for updating current time
  Timer? _timeUpdateTimer;

  // Getters
  PrayerSettings? get prayerSettings => _prayerSettings.value;
  PrayerTimes? get prayerTimes => _prayerTimes.value;
  NextPrayerInfo? get nextPrayerInfo => _nextPrayerInfo.value;
  int get hijriOffset => _hijriOffset.value;
  DateTime get currentTime => _currentTime.value;

  bool get isConfigured => _prayerSettings.value?.isValid ?? false;

  List<PrayerTimeData> get allPrayerTimes {
    final times = _prayerTimes.value;
    if (times == null) return [];
    // Assuming PrayerService.getAllPrayerTimes is static and correctly typed
    return PrayerService.getAllPrayerTimes(times);
  }

  HijriCalendar? get currentHijriDate {
    if (!isConfigured || _prayerTimes.value == null) {
      // check _prayerTimes.value also
      return PrayerService.getHijriDate(offset: _hijriOffset.value);
    }
    return PrayerService.getHijriDateWithMaghrib(
      offset: _hijriOffset.value,
      maghribTime: _prayerTimes.value!.maghrib, // Added null check safety
    );
  }

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
    _startTimeUpdateTimer();

    // Watch for changes in prayer times to update next prayer info
    ever(_prayerTimes, (PrayerTimes? times) {
      _updateNextPrayerInfo();
    });

    // Update next prayer info every minute implicitly via _currentTime changing
    // And nextPrayerInfo depends on currentTime
    ever(_currentTime, (DateTime time) {
      // Only update if prayer times are set, to avoid unnecessary calculations
      if (_prayerTimes.value != null) {
        _updateNextPrayerInfo();
      }
    });
  }

  @override
  void onClose() {
    _timeUpdateTimer?.cancel();
    super.onClose();
  }

  void _startTimeUpdateTimer() {
    _timeUpdateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        _currentTime.value = DateTime.now();
      },
    );
  }

  void _loadSettings() {
    final lat = SharedPreferencesService.getLatitude();
    final lng = SharedPreferencesService.getLongitude();
    final method = SharedPreferencesService.getMethod();
    final asrCalc = SharedPreferencesService.getAsrCalculation();
    final hijriOffset = SharedPreferencesService.getHijriDayOffset();

    if (lat != 0.0 && lng != 0.0 && method.isNotEmpty && asrCalc.isNotEmpty) {
      final settings = PrayerSettings(
        latitude: lat,
        longitude: lng,
        calculationMethod: method,
        asrCalculation: asrCalc,
      );

      _prayerSettings.value = settings;
      _updatePrayerTimes(); // This will also trigger _updateNextPrayerInfo via `ever`
    } else {
      // No valid settings loaded, ensure prayerTimes and nextPrayerInfo are null
      _prayerTimes.value = null;
      _nextPrayerInfo.value = null;
    }

    _hijriOffset.value = hijriOffset;
  }

  void updateSettings({
    required double latitude,
    required double longitude,
    required String calculationMethod,
    required String asrCalculation,
  }) {
    final settings = PrayerSettings(
      latitude: latitude,
      longitude: longitude,
      calculationMethod: calculationMethod,
      asrCalculation: asrCalculation,
    );

    _prayerSettings.value = settings;
    _savePrayerSettings(settings);
    _updatePrayerTimes(); // This will also trigger _updateNextPrayerInfo via `ever`
  }

  void updateHijriOffset(int offset) {
    _hijriOffset.value = offset;
    SharedPreferencesService.setHijriDayOffset(offset);
    // No need to manually update currentHijriDate here, it's a getter that will recompute
  }

  void _updatePrayerTimes() {
    final settings = _prayerSettings.value;
    if (settings == null || !settings.isValid) {
      _prayerTimes.value = null; // Clear times if settings are invalid
      return;
    }
    _prayerTimes.value = PrayerService.calculatePrayerTimes(settings);
  }

  void _updateNextPrayerInfo() {
    final times = _prayerTimes.value;
    if (times == null) {
      _nextPrayerInfo.value = null;
      return;
    }
    // Assuming PrayerService.getNextPrayerInfo is static and correctly typed
    _nextPrayerInfo.value = PrayerService.getNextPrayerInfo(times);
  }

  void _savePrayerSettings(PrayerSettings settings) {
    SharedPreferencesService.setLatitude(settings.latitude);
    SharedPreferencesService.setLongitude(settings.longitude);
    SharedPreferencesService.setMethod(settings.calculationMethod);
    SharedPreferencesService.setAsrCalculation(settings.asrCalculation);
  }

  String formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$displayHour:$minute $period';
  }

  String formatDuration(Duration duration) {
    if (duration.isNegative) {
      // Handle cases where time might have just passed
      return '00:00:00';
    }
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  String formatGeorgianDate(DateTime date) {
    const months = {
      1: 'يناير',
      2: 'فبراير',
      3: 'مارس',
      4: 'أبريل',
      5: 'مايو',
      6: 'يونيو',
      7: 'يوليو',
      8: 'أغسطس',
      9: 'سبتمبر',
      10: 'أكتوبر',
      11: 'نوفمبر',
      12: 'ديسمبر',
    };

    return '${date.day} ${months[date.month]} ${date.year}';
  }

  String formatHijriDate(HijriCalendar? hijri) {
    if (hijri == null) return 'جاري التحميل...'; // Or appropriate placeholder
    return '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear}';
  }
}
