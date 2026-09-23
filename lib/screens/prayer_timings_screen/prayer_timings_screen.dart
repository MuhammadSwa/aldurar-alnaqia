import 'dart:async';

import 'package:aldurar_alnaqia/common/helpers/app_platform.dart';
import 'package:aldurar_alnaqia/prayer/prayer_providers.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/city_directory.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_header_card.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_notification_dialog.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_settings_dialog.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_setup_required_dialog.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_card.dart';
import 'package:aldurar_alnaqia/services/prayer_notification_service.dart';
import 'package:aldurar_alnaqia/widgets/main_wrapper.dart' show rootScaffoldKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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
    ref.read(cityDirectoryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeAutoShowSettingsDialog();
    });
  }

  void _maybeAutoShowSettingsDialog() {
    if (_hasAutoShownSettings || !mounted) return;
    // Null view means unconfigured (prefs are ready before runApp, so there
    // is no separate loading state to wait for).
    if (ref.read(prayerViewProvider) != null) return;
    _hasAutoShownSettings = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (context) => const PrayerSettingsDialog(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Fires when the derived view appears (or settings change) after we've
    // already entered the page.
    ref.listen(prayerViewProvider, (previous, next) {
      if (previous == next) return;
      _maybeAutoShowSettingsDialog();
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
          tooltip: 'فتح القائمة',
        ),
        actions: [
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              unawaited(context.pushNamed(RouteNames.timingsSettings));
            },
          ),
          if (AppPlatform.isAndroid) const _NotifBell(),
        ],
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            PrayerHeaderCard(),
            SizedBox(height: 8),
            PrayerTimingsCard(),
          ],
        ),
      ),
    );
  }
}

/// Bell icon owning its own enabled flag: loads once in initState instead
/// of a `FutureBuilder` that re-fires on every parent rebuild, and refreshes
/// only itself via local `setState`.
class _NotifBell extends ConsumerStatefulWidget {
  const _NotifBell();

  @override
  ConsumerState<_NotifBell> createState() => _NotifBellState();
}

class _NotifBellState extends ConsumerState<_NotifBell> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    unawaited(isPrayerNotificationEnabled().then((value) {
      if (mounted) setState(() => _enabled = value);
    }));
  }

  Future<void> _refresh() async {
    final value = await isPrayerNotificationEnabled();
    if (mounted) setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'إشعار المواقيت',
      icon: Icon(
        _enabled ? Icons.notifications_active : Icons.notifications_off,
      ),
      onPressed: () async {
        // No timings yet (settings never saved) → prompt to set
        // them up first instead of the notification explainer.
        if (ref.read(prayerViewProvider) == null) {
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (context) => const PrayerSetupRequiredDialog(),
          );
          if (openSettings == true && context.mounted) {
            await showDialog<void>(
              context: context,
              builder: (context) => const PrayerSettingsDialog(),
            );
          }
          return;
        }
        if (_enabled) {
          // On → off straight away, no dialog.
          await setPrayerNotificationEnabled(false);
          await _refresh();
          return;
        }
        // Off → explain first, then enable from the dialog.
        final changed = await showDialog<bool>(
          context: context,
          builder: (context) => const PrayerNotificationDialog(),
        );
        // Refresh the bell icon when the dialog changed anything.
        if (changed == true) await _refresh();
      },
    );
  }
}
