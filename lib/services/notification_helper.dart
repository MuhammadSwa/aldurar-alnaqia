import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Requests the Android 13+ runtime notification permission.
///
/// The prayer-timings notification channel itself is created natively by
/// [PrayerNotificationService] (see android/.../PrayerNotificationService.kt);
/// nothing else in the app posts local notifications.
class NotificationHelper {
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }
}
