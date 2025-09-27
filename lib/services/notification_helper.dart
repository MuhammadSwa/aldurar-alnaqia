import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'prayer_timing_channel',
    'مواقيت الصلاة',
    description: 'إشعار دائم يعرض مواقيت الصلاة والعد التنازلي للصلاة التالية',
    importance: Importance.low, // Persistent, non-intrusive
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _fln.initialize(initSettings);

    // Create the channel
    final android = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    // Default small icon is taken from AndroidInitializationSettings

    // Request notification permission on Android 13+
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
  }
}
