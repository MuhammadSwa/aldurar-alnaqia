import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';
import 'package:aldurar_alnaqia/services/prayer_notification_service.dart';
import 'package:aldurar_alnaqia/utils/showSnackbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettings extends StatefulWidget {
  const NotificationSettings({super.key});

  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  final PrayerTimingsController _controller =
      Get.put(PrayerTimingsController());
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    // Check both the app's logical state and the platform service state
    final prefs = await SharedPreferences.getInstance();
    final prefEnabled =
        prefs.getBool(PrayerNotificationService.notificationEnabledKey);
    // prefs.getBool(PrayerNotificationService.notificationEnabledKey, false);
    bool platformServiceRunning =
        await PrayerNotificationService.isPlatformServiceRunning();

    if (mounted) {
      setState(() {
        // UI should reflect if the user *intended* it to be on (prefEnabled)
        // AND if the service is actually capable of running (platformServiceRunning can be a good indicator)
        // Or simply, if our Dart logic is supposed to be running.
        _notificationsEnabled = PrayerNotificationService
            .isServiceRunning; // Uses the Dart logic flag

        // More robust check:
        // _notificationsEnabled = prefEnabled && platformServiceRunning;
        // If prefEnabled is true but platformServiceRunning is false (after app restart before service auto-starts),
        // this might briefly show "off". PrayerNotificationService.isServiceRunning is simpler for UI logic.
      });
    }
  }

  Future<void> _toggleNotifications() async {
    // Optimistically update UI first
    // bool newNotificationsEnabledState = !_notificationsEnabled; // Calculate future state

    try {
      if (PrayerNotificationService.isServiceRunning) {
        // If currently ON (by Dart logic flag)
        await _controller.stopPrayerNotifications();
        setState(() {
          _notificationsEnabled = false;
        }); // Update after successful stop
        if (mounted) {
          showSnackBar(context, 'تم إيقاف إشعارات العد التنازلي للصلاة');
        }
      } else {
        // If currently OFF
        await _controller.startPrayerNotifications();
        // After startService, isServiceRunning should be true
        setState(() {
          _notificationsEnabled = PrayerNotificationService.isServiceRunning;
        });
        if (mounted && PrayerNotificationService.isServiceRunning) {
          showSnackBar(context, 'سيتم عرض العد التنازلي للصلاة في الإشعارات');
        } else if (mounted && !PrayerNotificationService.isServiceRunning) {
          showSnackBar(
              context, 'لم يتم تفعيل الإشعارات، يرجى التحقق من الأذونات.');
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'حدث خطأ في تفعيل الإشعارات: $e');
      }
      // Re-check status on error to ensure UI is consistent
      await _checkNotificationStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أوقات الصلاة'),
        actions: [
          IconButton(
            icon: Icon(
              _notificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: _notificationsEnabled ? Colors.green : Colors.grey,
            ),
            onPressed: _toggleNotifications,
            tooltip:
                _notificationsEnabled ? 'إيقاف الإشعارات' : 'تفعيل الإشعارات',
          ),
        ],
      ),
      body: Obx(() {
        if (!_controller.isInitialized.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.prayerTimings == null) {
          return const Center(
            child: Text(
              'يرجى تحديد الموقع وإعدادات الصلاة',
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        final prayerTimes = PrayerTimeings.getFormattedPrayerTimes();
        final timeLeft = _controller.timeLeftForNextPrayer.value;
        final duration = timeLeft.$1;
        final nextPrayer = timeLeft.$2;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Next Prayer Countdown Card
              Card(
                elevation: 4,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'الوقت المتبقي لصلاة $nextPrayer',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${duration.inHours.toString().padLeft(2, '0')}:'
                        '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
                        '${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _notificationsEnabled
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _notificationsEnabled
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _notificationsEnabled
                                  ? Icons.notifications_active
                                  : Icons.notifications_off,
                              size: 16,
                              color: _notificationsEnabled
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _notificationsEnabled
                                  ? 'الإشعارات مفعلة'
                                  : 'الإشعارات متوقفة',
                              style: TextStyle(
                                color: _notificationsEnabled
                                    ? Colors.green
                                    : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Prayer Times List
              Expanded(
                child: Card(
                  elevation: 4,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'أوقات الصلاة اليوم',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (prayerTimes != null) ...[
                        _buildPrayerTimeRow('الفجر', prayerTimes['fajr']!),
                        _buildPrayerTimeRow('الشروق', prayerTimes['sunrise']!),
                        _buildPrayerTimeRow('الظهر', prayerTimes['dhuhr']!),
                        _buildPrayerTimeRow('العصر', prayerTimes['asr']!),
                        _buildPrayerTimeRow('المغرب', prayerTimes['maghrib']!),
                        _buildPrayerTimeRow('العشاء', prayerTimes['isha']!),
                      ],
                    ],
                  ),
                ),
              ),

              // Toggle Notifications Button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 16),
                child: ElevatedButton.icon(
                  onPressed: _toggleNotifications,
                  icon: Icon(
                    _notificationsEnabled
                        ? Icons.notifications_off
                        : Icons.notifications_active,
                  ),
                  label: Text(
                    _notificationsEnabled
                        ? 'إيقاف الإشعارات'
                        : 'تفعيل الإشعارات',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _notificationsEnabled ? Colors.orange : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildPrayerTimeRow(String prayer, String time) {
    final currentPrayer = PrayerTimeings.getCurrentPrayer();
    final isCurrentPrayer = currentPrayer != null &&
        ((prayer == 'الفجر' && currentPrayer == 'fajr') ||
            (prayer == 'الشروق' && currentPrayer == 'sunrise') ||
            (prayer == 'الظهر' && currentPrayer == 'dhuhr') ||
            (prayer == 'العصر' && currentPrayer == 'asr') ||
            (prayer == 'المغرب' && currentPrayer == 'maghrib') ||
            (prayer == 'العشاء' && currentPrayer == 'isha'));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentPrayer
            ? Colors.green.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentPrayer ? Colors.green : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (isCurrentPrayer) ...[
                const Icon(
                  Icons.circle,
                  color: Colors.green,
                  size: 12,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                prayer,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      isCurrentPrayer ? FontWeight.bold : FontWeight.normal,
                  color: isCurrentPrayer ? Colors.green : Colors.black87,
                ),
              ),
            ],
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isCurrentPrayer ? Colors.green : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationPermissionDialog extends StatelessWidget {
  final VoidCallback onPermissionGranted;

  const NotificationPermissionDialog({
    Key? key,
    required this.onPermissionGranted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تفعيل الإشعارات'),
      content: const Text(
        'لتلقي إشعارات العد التنازلي للصلاة حتى عند إغلاق التطبيق، '
        'يجب السماح للتطبيق بإرسال الإشعارات والعمل في الخلفية.\n\n'
        'قد تحتاج إلى إضافة التطبيق إلى قائمة التطبيقات المستثناة '
        'من توفير البطارية في إعدادات الجهاز.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('لاحقاً'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onPermissionGranted();
          },
          child: const Text('تفعيل'),
        ),
      ],
    );
  }
}
