// lib/services/prayer_notification_service.dart

import 'dart:async';
import 'dart:ui';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

@pragma('vm:entry-point')
class PrayerNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'prayer_countdown_channel';
  static const String _channelName = 'Prayer Countdown';
  static const String _channelDescription = 'Shows countdown to next prayer';
  static const int _notificationId = 1001;

  static const String _prefsName = "PrayerAppPrefs";
  static const String notificationEnabledKey = "prayer_notification_enabled";

  static Timer? _timer;
  static bool _isDartServiceLogicRunning = false;
  static bool _isTimezoneInitialized = false;
  static ServiceInstance? _currentServiceInstance; // Store service instance

  /// Initialize timezone data with better error handling and caching
  static Future<void> _initializeTimezone() async {
    if (_isTimezoneInitialized) {
      print('PrayerNotificationService: Timezone already initialized');
      return;
    }

    try {
      tz_data.initializeTimeZones();

      final String currentTimeZone =
          await FlutterTimezone.getLocalTimezone().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print(
              'PrayerNotificationService: Timezone detection timeout, using system default');
          return 'UTC';
        },
      );

      tz.setLocalLocation(tz.getLocation(currentTimeZone));
      _isTimezoneInitialized = true;
      print(
          'PrayerNotificationService: Timezone initialized to ${tz.local.name}');
    } catch (e) {
      print('PrayerNotificationService: Failed to initialize timezone: $e');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
        _isTimezoneInitialized = true;
        print('PrayerNotificationService: Fallback to UTC timezone');
      } catch (fallbackError) {
        print(
            'PrayerNotificationService: Even UTC fallback failed: $fallbackError');
      }
    }
  }

  /// Initialize the notification service
  static Future<void> initialize() async {
    print('PrayerNotificationService: Starting initialization...');
    await _initializeTimezone();
    await _initializeNotifications();
    await _initializeBackgroundService();
    print('PrayerNotificationService: Initialization completed');
  }

  /// Initialize local notifications
  static Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Initialize background service with immediate prayer time
  static Future<void> _initializeBackgroundService() async {
    final service = FlutterBackgroundService();

    String initialTitle = 'أوقات الصلاة';
    String initialContent = 'جاري حساب الأوقات...';

    try {
      final timeLeftData = PrayerTimeings.timeLeftForNextPrayer();
      final duration = timeLeftData.$1;
      final prayerName = timeLeftData.$2;

      if (prayerName.isNotEmpty &&
          !duration.isNegative &&
          duration.inSeconds > 0) {
        initialTitle = 'الوقت المتبقي لصلاة $prayerName';
        initialContent = _formatDuration(duration);
      }
    } catch (e) {
      print('PrayerNotificationService: Could not get initial prayer time: $e');
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: initialTitle,
        initialNotificationContent: initialContent,
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );
  }

  /// Request necessary permissions
  static Future<void> _requestPermissions() async {
    await Permission.notification.request();

    if (GetPlatform.isAndroid) {
      await Permission.scheduleExactAlarm.request();
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  /// Start the persistent notification service
  static Future<void> startService() async {
    print('PrayerNotificationService: Starting service...');

    if (!(await Permission.notification.isGranted)) {
      await _requestPermissions();
      if (!(await Permission.notification.isGranted)) {
        print("Notification permission not granted. Cannot start service.");
        return;
      }
    }

    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();

    if (isRunning && _isDartServiceLogicRunning) {
      print("PrayerNotificationService: Service logic already active.");
      return;
    }

    // Show immediate notification before starting service
    await _updatePrayerTimeNotificationLogic(null);

    await service.startService();
    _isDartServiceLogicRunning = true;

    // **FIX: Wait a moment for service to fully start, then start our timer**
    Timer(const Duration(milliseconds: 500), () {
      _startPrayerCountdownTimer(null);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationEnabledKey, true);
    print("PrayerNotificationService: Service started successfully");

    // Start workmanager backup
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      "prayer-countdown-backup-task",
      "prayerCountdownBackupTask",
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }

  /// Stop the notification service
  /// Stop the notification service
  static Future<void> stopService() async {
    print('PrayerNotificationService: Stopping service...');
    final service = FlutterBackgroundService();

    // 1. If the service is running, tell it to stop.
    // The 'stopService' handler inside onStart() is the only part that
    // should be responsible for stopping the service and its notification.
    if (await service.isRunning()) {
      service.invoke("stopService");
    }

    // 2. Cancel the backup WorkManager task to prevent it from reviving the notification.
    await Workmanager().cancelByUniqueName("prayer-countdown-backup-task");

    // 3. Update the preference to reflect the disabled state. This is crucial.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationEnabledKey, false);

    // 4. Clean up the main isolate's state.
    _timer?.cancel();
    _timer = null;
    _isDartServiceLogicRunning = false;
    _currentServiceInstance = null;

    // 5. As a final safety net, clear any notifications. This will catch any
    // orphaned notifications if the service didn't shut down cleanly. We add
    // a small delay to give the service time to process the 'stopService' invoke.
    await Future.delayed(const Duration(milliseconds: 500));
    await _notificationsPlugin.cancelAll();

    print("PrayerNotificationService: Service stop process initiated.");
  }

  /// Background service entry point
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    print('PrayerNotificationService: Background service starting...');

    DartPluginRegistrant.ensureInitialized();
    await SharedPreferencesService().init();

    _initializeTimezone().catchError((e) {
      print(
          'PrayerNotificationService: Background timezone initialization failed: $e');
    });

    _isDartServiceLogicRunning = true;
    _currentServiceInstance = service; // Store service instance

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "خدمة أوقات الصلاة",
        content: "الخدمة تعمل في الخلفية للحفاظ على دقة التنبيهات.",
      );

      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

// In your onStart method, improve the stopService event handler:
    service.on('stopService').listen((event) async {
      print('PrayerNotificationService: Received stop service event');

      // Cancel the timer first
      _timer?.cancel();
      _timer = null;
      _isDartServiceLogicRunning = false;
      _currentServiceInstance = null;

      // For Android, ensure foreground service notification is cleared
      if (service is AndroidServiceInstance) {
        try {
          // Try to set the service as background first to clear foreground notification
          service.setAsBackgroundService();
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('PrayerNotificationService: Error setting as background: $e');
        }
      }

      // Stop the service
      await service.stopSelf();
      print('PrayerNotificationService: Service stopped via event handler');
    });

    print("PrayerNotificationService: Starting countdown timer...");
    _startPrayerCountdownTimer(service);
  }

  /// Start the prayer countdown timer - **IMPROVED VERSION**
  static void _startPrayerCountdownTimer(ServiceInstance? service) {
    _timer?.cancel();

    // Update immediately first
    _updatePrayerTimeNotificationLogic(service ?? _currentServiceInstance);

    // Then start the recurring timer
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updatePrayerTimeNotificationLogic(service ?? _currentServiceInstance);
    });
    print("PrayerNotificationService: Countdown timer started successfully");
  }

  /// Updates the notification using the efficient service instance method.
  static Future<void> _updatePrayerTimeNotificationLogic(
      ServiceInstance? service) async {
    try {
      // 1. Get the raw prayer time data
      final timeLeftData = PrayerTimeings.timeLeftForNextPrayer();
      final prayerName = timeLeftData.$2;

      // 2. Check if we have a valid next prayer
      if (prayerName.isEmpty) {
        // If no prayer is found, show a generic message and don't start a countdown
        await _showNotification(
          'أوقات الصلاة',
          'جاري حساب الوقت للصلاة القادمة...',
          ongoing: true,
        );
        return;
      }

      // 3. Calculate the exact future time for the countdown
      final prayerTimes = PrayerTimeings.getPrayersTimings();
      final nextPrayerTime =
          prayerTimes?.timeForPrayer(prayerTimes.nextPrayer());

      if (nextPrayerTime == null) {
        // Handle edge case where time couldn't be found
        await _showNotification(
          'الوقت المتبقي لصلاة $prayerName',
          'جاري الحساب...',
          ongoing: true,
        );
        return;
      }

      // 4. Create the notification with the countdown
      final title = 'الوقت المتبقي لصلاة $prayerName';
      final body =
          'يبدأ في تمام الساعة ${_formatTime(tz.TZDateTime.from(nextPrayerTime, tz.local))}'; // Informative body text

      await _showNotification(
        title,
        body,
        ongoing: true,
        countdownUntil: nextPrayerTime, // Pass the target time here!
        payload: 'timings',
      );
    } catch (e, s) {
      print('Error in _updatePrayerTimeNotificationLogic: $e\n$s');
      // Handle errors as before
    }
  }

// Add this helper function inside PrayerNotificationService to format time nicely
  static String _formatTime(tz.TZDateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = dateTime.hour >= 12 ? 'م' : 'ص';
    return '$hour:$minute $amPm';
  }

  /// Clear all prayer notifications
  static Future<void> clearAllNotifications() async {
    try {
      await _notificationsPlugin.cancel(_notificationId);
      await _notificationsPlugin.cancelAll();
      print('PrayerNotificationService: All notifications cleared');
    } catch (e) {
      print('PrayerNotificationService: Error clearing notifications: $e');
    }
  }

  /// Formats duration into HH:MM:SS or MM:SS string
  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final String hoursStr = hours.toString().padLeft(2, '0');
    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hoursStr:$minutesStr:$secondsStr';
    } else {
      return '$minutesStr:$secondsStr';
    }
  }

  /// Show a one-off notification. Now used as a fallback or for WorkManager.
  static Future<void> _showNotification(
    String title,
    String body, {
    bool ongoing = false,
    DateTime? countdownUntil,
    String? payload,
  }) async {
    try {
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: ongoing,
        autoCancel: false,
        showWhen: countdownUntil != null,
        when: countdownUntil?.millisecondsSinceEpoch,
        usesChronometer: countdownUntil != null,
        chronometerCountDown: true,
        playSound: false,
        enableVibration: false,
        icon: 'drawable/ic_stat_dome',
        ticker: 'Prayer Countdown',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentSound: false,
        presentAlert: true,
        presentBadge: false,
        interruptionLevel: InterruptionLevel.passive,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(_notificationId, title, body, details,
          payload: payload);
    } catch (e) {
      print('PrayerNotificationService: Error showing notification: $e');
    }
  }

  /// Handle notification tap
  @pragma('vm:entry-point') // Good practice for background callbacks
  static void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped with payload: ${response.payload}');

    // The payload is the route name we want to navigate to.
    // We check if it's not null and not empty for safety.
    if (response.payload != null && response.payload!.isNotEmpty) {
      // Use GetX to navigate. This works because GetMaterialApp sets up a global
      // navigator that can be accessed from anywhere once the app is running.
      // The OS launches the app first, then this callback fires,
      // so the navigation context is ready.
      Get.toNamed('/${response.payload!}'); // e.g., Get.toNamed('/timings')
    }
  }

  /// Check platform service status
  static Future<bool> isPlatformServiceRunning() async {
    return await FlutterBackgroundService().isRunning();
  }

  /// Check if Dart logic is running
  static bool get isServiceRunning => _isDartServiceLogicRunning;

  /// **NEW: Manual timer start method for immediate UI updates**
  static void ensureTimerRunning() {
    if (_isDartServiceLogicRunning && _timer == null) {
      _startPrayerCountdownTimer(_currentServiceInstance);
    }
  }
}

/// Workmanager callback
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    print("WorkManager: Task $taskName executing.");
    try {
      DartPluginRegistrant.ensureInitialized();

      // **FIX**: Initialize SharedPreferences to check the user's preference
      final prefs = await SharedPreferences.getInstance();
      final bool notificationsEnabled =
          prefs.getBool(PrayerNotificationService.notificationEnabledKey) ??
              false;

      // **FIX**: If user turned notifications off, abort the task.
      if (!notificationsEnabled) {
        print(
            "WorkManager: Notifications are disabled by user. Aborting task.");
        // We can also ensure any stray notifications are gone.
        await PrayerNotificationService.initialize();
        await PrayerNotificationService.clearAllNotifications();
        return true; // Success, we respected the user's setting.
      }

      // If we are here, notifications are enabled. Proceed with original logic.
      await PrayerNotificationService.initialize();

      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        print(
            "WorkManager: Service is not running, but should be. Restarting service.");
        // Restart the service properly.
        await PrayerNotificationService.startService();
      } else {
        print("WorkManager: Service is already running. Task complete.");
      }

      return true;
    } catch (e) {
      print('WorkManager error: $e');
      return false; // Indicate failure so WorkManager can retry.
    }
  });
}
