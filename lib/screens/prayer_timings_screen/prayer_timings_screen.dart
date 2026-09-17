import 'package:aldurar_alnaqia/common/helpers/app_platform.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/city_directory.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/next_prayer_countdown.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_settings_screen.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_date_row.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_notification_dialog.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_setup_required_dialog.dart';
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
  // Ensures the settings dialog auto-opens only once per route visit
  // when prayer timings can't be calculated (e.g. no location yet).
  bool _hasAutoShownSettings = false;

  @override
  void initState() {
    super.initState();
    // Warm the city directory while the user reads the timings so the
    // settings dialog and city search open instantly (the 2.3 MB asset
    // parse now runs on a background isolate, but starting it early
    // still hides its latency behind this screen).
    // ignore: unused_result
    ref.read(cityDirectoryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeAutoShowSettingsDialog();
    });
  }

  void _maybeAutoShowSettingsDialog() {
    if (_hasAutoShownSettings || !mounted) return;
    final prayerState = ref.read(prayerProvider);
    if (!prayerState.isInitialized) return;
    if (prayerState.schedule != null) return;
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
          previous?.schedule == next.schedule) {
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
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PrayerTimingsSettingsScreen(),
                ),
              );
            },
          ),
          if (AppPlatform.isAndroid)
            FutureBuilder<bool>(
              future: isPrayerNotificationEnabled(),
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? false;
                return IconButton(
                  tooltip: 'إشعار المواقيت',
                  icon: Icon(
                    enabled
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                  ),
                  onPressed: () async {
                    // No timings yet (settings never saved) → prompt to set
                    // them up first instead of the notification explainer.
                    if (ref.read(prayerProvider).schedule == null) {
                      final openSettings = await showDialog<bool>(
                        context: context,
                        builder: (context) =>
                            const PrayerSetupRequiredDialog(),
                      );
                      if (openSettings == true && context.mounted) {
                        await showDialog(
                          context: context,
                          builder: (context) =>
                              const PrayerSettingsDialog(),
                        );
                      }
                      return;
                    }
                    if (enabled) {
                      // On → off straight away, no dialog.
                      await setPrayerNotificationEnabled(false);
                      if (mounted) setState(() {});
                      return;
                    }
                    // Off → explain first, then enable from the dialog.
                    final changed = await showDialog<bool>(
                      context: context,
                      builder: (context) =>
                          const PrayerNotificationDialog(),
                    );
                    // Refresh the bell icon when the dialog changed anything.
                    if (changed == true && mounted) setState(() {});
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
            PrayerDateRow(),
            SizedBox(height: 8),
            NextPrayerCountdown(),
            SizedBox(height: 8),
            PrayerTimingsCard(),
          ],
        ),
      ),
    );
  }
}
