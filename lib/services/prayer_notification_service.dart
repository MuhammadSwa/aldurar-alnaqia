// lib/services/prayer_notification_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz; // For timezone
import 'package:timezone/data/latest.dart' as tz_data;

class PrayerNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'prayer_countdown_channel';
  static const String _channelName = 'Prayer Countdown';
  static const String _channelDescription = 'Shows countdown to next prayer';
  static const int _notificationId =
      1001; // Used for both local_notif and foreground service

  // SharedPreferences keys (must match BootReceiver.kt)
  static const String _prefsName = "PrayerAppPrefs";
  static const String notificationEnabledKey = "prayer_notification_enabled";

  static Timer? _timer;
  static bool _isDartServiceLogicRunning =
      false; // Tracks if our Dart logic for service is active

  /// Initialize timezone data and set local timezone
  static Future<void> _initializeTimezone() async {
    try {
      tz_data.initializeTimeZones();
      final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
      print(
          'PrayerNotificationService: Timezone initialized to ${tz.local.name} in current isolate.');
    } catch (e) {
      print(
          'PrayerNotificationService: Failed to initialize timezone: $e. Prayer times might be inaccurate.');
      // Fallback: Attempt to use a stored timezone if available, or default to UTC.
      // This part depends on how you manage timezone settings globally.
      // For now, adhan_dart might use system default or UTC if tz.local is not set.
    }
  }

  /// Initialize the notification service
  static Future<void> initialize() async {
    await _initializeTimezone(); // Initialize for the main isolate context
    await _initializeNotifications();
    await _initializeBackgroundService();
// Request permissions after basic setup, often better to ask contextually.
    // await _requestPermissions(); // Consider moving this to when user enables notifications
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

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.low, // Low importance for ongoing, less intrusive
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Initialize background service
  static Future<void> _initializeBackgroundService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // We manage start/stop, and BootReceiver handles boot
        isForegroundMode: true,
        notificationChannelId: _channelId, // Use the same channel
        initialNotificationTitle: 'أوقات الصلاة', // Initial title
        initialNotificationContent: 'جاري التهيئة...', // Initial content
        foregroundServiceNotificationId:
            _notificationId, // Crucial: links this to your local notification
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        // onBackground: onIosBackground, // only if you have specific iOS background logic
      ),
    );
  }

  /// Request necessary permissions
  static Future<void> _requestPermissions() async {
    // Request notification permission
    await Permission.notification.request();

    // Request background app refresh for iOS
    // iOS permissions are typically handled by flutter_local_notifications init
    // if (GetPlatform.isIOS) {
    //   await Permission.backgroundRefresh.request();
    // }

    // Request exact alarm permission for Android 12+
    if (GetPlatform.isAndroid) {
      await Permission.scheduleExactAlarm
          .request(); // For precise scheduling if needed
      await Permission.ignoreBatteryOptimizations
          .request(); // Explain why this is needed
    }
  }

  /// Start the persistent notification service
  static Future<void> startService() async {
    // Request permissions before starting, if not already granted
    if (!(await Permission.notification.isGranted)) {
      await _requestPermissions();
      if (!(await Permission.notification.isGranted)) {
        print("Notification permission not granted. Cannot start service.");
        // Optionally, inform the user via UI.
        return;
      }
    }
    if (GetPlatform.isAndroid &&
        !(await Permission.ignoreBatteryOptimizations.isGranted)) {
      // Guide user to allow battery optimization exemption if it's critical
      print("Battery optimization not ignored. Service might be killed.");
    }

    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();

    if (isRunning && _isDartServiceLogicRunning) {
      print("PrayerNotificationService: Service logic already active.");
      return;
    }

    // Start background service
    await service.startService(); // Starts the platform service
    _isDartServiceLogicRunning = true; // Mark our Dart logic as active

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationEnabledKey, true);
    print("PrayerNotificationService: Service started, preference set.");

    // Also start workmanager for backup
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      "prayer-countdown-backup-task", // Unique name
      "prayerCountdownBackupTask",
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.keep, // Or replace
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
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke(
        "stopService"); // Tell the Dart isolate to stop its timer and clean up

    await Workmanager().cancelByUniqueName("prayer-countdown-backup-task");
    await _notificationsPlugin
        .cancel(_notificationId); // Cancel our specific notification

    _timer?.cancel();
    _timer = null;
    _isDartServiceLogicRunning = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationEnabledKey, false);
    print("PrayerNotificationService: Service stopped, preference cleared.");
  }

  /// Background service entry point
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized(); // Crucial for plugins
    await _initializeTimezone(); // Initialize timezone for this background isolate
    _isDartServiceLogicRunning =
        true; // Mark Dart logic as active within this isolate

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) async {
      _timer?.cancel();
      _timer = null;
      _isDartServiceLogicRunning = false;
      // The SharedPreferences flag is set by the main stopService call.
      // No need to cancel _notificationId here, as flutter_background_service manages its lifecycle
      // when stopSelf() is called, or it's handled by the main stopService.
      service.stopSelf(); // Stops the platform service
    });

    print(
        "PrayerNotificationService (onStart): Starting countdown timer logic.");
    _startPrayerCountdownTimer(service);
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    // iOS background execution is limited.
    // DartPluginRegistrant.ensureInitialized();
    // await _initializeTimezone();
    // Perform a single update or short task.
    print("PrayerNotificationService: onIosBackground invoked.");
    // await _updatePrayerTimeNotificationLogic(service); // Example for a single update
    return true;
  }

  /// Start the prayer countdown timer
  static void _startPrayerCountdownTimer(ServiceInstance? service) {
    _timer?.cancel();
    print("PrayerNotificationService: Countdown timer initiated.");

    // Perform an immediate update
    _updatePrayerTimeNotificationLogic(service);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updatePrayerTimeNotificationLogic(service);
    });
  }

  /// Contains the logic to calculate time and update notification
  static Future<void> _updatePrayerTimeNotificationLogic(
      ServiceInstance? service) async {
    try {
      // Directly use the static method from PrayerTimeings
      // This avoids GetX dependency in the background isolate directly.
      // Ensure PrayerTimeings.timeLeftForNextPrayer() can access SharedPreferences.
      final timeLeftData = PrayerTimeings.timeLeftForNextPrayer();
      final duration = timeLeftData.$1;
      final prayerName = timeLeftData.$2;

      String title;
      String body;

      if (prayerName.isEmpty ||
          duration.isNegative ||
          duration.inSeconds <= 0) {
        // This can happen if it's past Isha and next Fajr calculation needs a new day's data.
        // PrayerTimeings.timeLeftForNextPrayer() should ideally handle this rollover.
        title = 'أوقات الصلاة';
        body = 'جاري حساب الوقت...';
        // The PrayerTimeings class should be robust enough to provide the next prayer
        // even if it's for the next day.
      } else {
        final hours = duration.inHours;
        final minutes = duration.inMinutes.remainder(60);
        final seconds = duration.inSeconds.remainder(60);

        String timeText;
        if (hours > 0) {
          timeText =
              '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        } else if (minutes > 0) {
          timeText =
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        } else {
          timeText = '${seconds.toString().padLeft(2, '0')} ثانية';
        }
        title = 'الوقت المتبقي لصلاة $prayerName';
        body = timeText;
      }

      // This updates the notification that flutter_background_service uses for foreground status
      // AND it's our custom local notification because we used the same _notificationId.
      await _showNotification(title, body, ongoing: true);
    } catch (e, s) {
      print('Error in _updatePrayerTimeNotificationLogic: $e\n$s');
      await _showNotification(
        'خطأ في حساب الصلاة',
        'يرجى فتح التطبيق للتحقق.',
        ongoing: true,
      );
    }
  }

  /// Show notification
  static Future<void> _showNotification(
    String title,
    String body, {
    bool ongoing = false,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: ongoing,
      autoCancel: false, // Not cancellable by swipe if ongoing
      showWhen:
          false, // Don't show timestamp in notification tray if not needed
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation:
          BigTextStyleInformation(body), // If you want expandable text
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentSound: false,
      presentAlert:
          true, // For iOS, alert is how it's shown. Might be less "persistent".
      presentBadge: false,
      interruptionLevel: InterruptionLevel.passive,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      _notificationId, // Consistent ID
      title,
      body,
      details,
    );
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Implement navigation if needed, e.g., open the app to the prayer times screen.
    // This requires setup in MainActivity and handling the intent.
  }

  /// Use this to check the actual platform service status
  static Future<bool> isPlatformServiceRunning() async {
    return await FlutterBackgroundService().isRunning();
  }

  /// This reflects if our Dart logic for the service *should* be running
  static bool get isServiceRunning => _isDartServiceLogicRunning;
}

/// Workmanager callback dispatcher
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    print("WorkManager: Task $taskName executing.");
    DartPluginRegistrant.ensureInitialized();
    await PrayerNotificationService
        ._initializeTimezone(); // Initialize timezone for WorkManager isolate

    try {
      // Backup prayer time calculation in case background service fails
// In WorkManager, a less frequent update is expected.
      // We can simplify the notification content.
      final timeLeft = PrayerTimeings.timeLeftForNextPrayer();
      final duration = timeLeft.$1;
      final prayerName = timeLeft.$2;

      if (duration.inSeconds > 0 && prayerName.isNotEmpty) {
        final hours = duration.inHours;
        final minutes = duration.inMinutes.remainder(60);

        String timeText;
        if (hours > 0) {
          timeText = '$hoursس $minutesد';
        } else if (minutes > 0) {
          timeText = '$minutesد';
        } else {
          timeText = 'أقل من دقيقة';
        }

        // Use the same _showNotification method, but it will be less frequent
        await PrayerNotificationService._showNotification(
          'صلاة $prayerName بعد', // Slightly different title for backup
          timeText,
          ongoing: true, // Still ongoing as it's part of the persistent display
        );
        print("WorkManager: Notification updated for $prayerName.");
        return true;
      } else {
        print(
            "WorkManager: No valid prayer time found to update notification.");
        return false; // Indicate failure if no data to show
      }

      return Future.value(true);
    } catch (e) {
      print('Error in workmanager task: $e');
      return false; // Indicate failure
    }
  });
}

/// Extension to easily start/stop prayer notifications
extension PrayerTimingsControllerExtension on PrayerTimingsController {
  /// Start prayer countdown notifications
  Future<void> startPrayerNotifications() async {
    await PrayerNotificationService.startService();
  }

  /// Stop prayer countdown notifications
  Future<void> stopPrayerNotifications() async {
    await PrayerNotificationService.stopService();
  }

  // Consider renaming to reflect Dart logic state vs. platform service state
  bool get areNotificationsEnabledByAppLogic =>
      PrayerNotificationService.isServiceRunning;
  Future<bool> get isUnderlyingPlatformServiceRunning async =>
      await PrayerNotificationService.isPlatformServiceRunning();

  /// Check if notifications are running
  bool get areNotificationsRunning =>
      PrayerNotificationService.isServiceRunning;
}
