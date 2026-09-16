import 'package:aldurar_alnaqia/common/helpers/app_platform.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/day_name.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/next_prayer_countdown.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_action_buttons.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_date_row.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_settings_dialog.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_card.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart'
    show prayerProvider;
import 'package:aldurar_alnaqia/services/prayer_notification_service.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrayerTimingsScreen extends ConsumerStatefulWidget {
  const PrayerTimingsScreen({super.key});

  @override
  ConsumerState<PrayerTimingsScreen> createState() =>
      _PrayerTimingsScreenState();
}

class _PrayerTimingsScreenState extends ConsumerState<PrayerTimingsScreen> {
  // True while the native prayer service is starting/stopping after a bell
  // tap — shows a spinner until the notification actually appears/disappears.
  bool _togglingNotification = false;

  // Ensures the settings dialog auto-opens only once per route visit
  // when prayer timings can't be calculated (e.g. no location yet).
  bool _hasAutoShownSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeAutoShowSettingsDialog();
    });
  }

  void _maybeAutoShowSettingsDialog() {
    if (_hasAutoShownSettings || !mounted) return;
    final prayerState = ref.read(prayerProvider);
    if (!prayerState.isInitialized) return;
    if (prayerState.prayerTimings != null) return;
    _hasAutoShownSettings = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => const PrayerSettingsDialog(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Fires when the async provider finishes init (or settings change)
    // after we've already entered the page.
    ref.listen(prayerProvider, (previous, next) {
      if (previous?.isInitialized == next.isInitialized &&
          previous?.prayerTimings == next.prayerTimings) {
        return;
      }
      _maybeAutoShowSettingsDialog();
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () =>
              ref.read(rootScaffoldKeyProvider).currentState?.openDrawer(),
          tooltip: 'فتح القائمة',
        ),
        actions: [
          if (AppPlatform.isAndroid)
            FutureBuilder<bool>(
              future: isPrayerNotificationEnabled(),
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? false;
                return IconButton(
                  tooltip:
                      enabled ? 'إيقاف إشعار المواقيت' : 'تشغيل إشعار المواقيت',
                  icon: _togglingNotification
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          enabled
                              ? Icons.notifications_active
                              : Icons.notifications_off,
                        ),
                  onPressed: _togglingNotification
                      ? null
                      : () async {
                          setState(() => _togglingNotification = true);
                          final newValue = !enabled;
                          await setPrayerNotificationEnabled(newValue);
                          // Wait until the service actually started/stopped
                          // so the spinner reflects the real notification.
                          await waitUntilPrayerNotificationState(newValue);
                          if (!mounted) return;
                          setState(() => _togglingNotification = false);
                        },
                );
              },
            ),
        ],
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            PrayerActionButtonsRow(),
            SizedBox(height: 14),
            PrayerDateRow(),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ArabicDayNameWidget(),
                ),
                SizedBox(width: 16), // Space between widgets
                Expanded(
                  child: NextPrayerCountdown(),
                ),
              ],
            ),
            SizedBox(height: 8),
            PrayerTimingsCard(),
          ],
        ),
      ),
    );
  }
}
