import 'dart:async';
import 'dart:math';
import 'package:aldurar_alnaqia/MyDrawer.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/day_name.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/next_prayer_countdown.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_card.dart';
import 'package:aldurar_alnaqia/widgets/main_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/adjust_hijri_day_dialogBox.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_settings_dialog.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/hijri_date_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';
import 'package:text_responsive/text_responsive.dart';

class PrayerTimingsScreen extends StatefulWidget {
  const PrayerTimingsScreen({super.key});

  @override
  State<PrayerTimingsScreen> createState() => _PrayerTimingsScreenState();
}

class _PrayerTimingsScreenState extends State<PrayerTimingsScreen> {
  // The ScaffoldKey should be part of the State, not static.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    // --- REFACTORED: Initialize controllers here, safely and only once. ---
    // fenix: true ensures they persist even if this screen is removed from the widget tree.
    Get.lazyPut(() => PrayerTimingsController(), fenix: true);
    Get.lazyPut(() => HijriOffsetController(), fenix: true);

    // You can also initialize your drawer controller here if it's specific to this screen
    // or keep it in main() if it's truly global.
    Get.lazyPut(() => GlobalDrawerController(), fenix: true);
  }

  @override
  Widget build(BuildContext context) {
    // Get the global drawer controller
    final drawerController = Get.find<GlobalDrawerController>();
    // Register this scaffold key
    drawerController.registerScaffoldKey(_scaffoldKey);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'فتح القائمة',
        ),
      ),
      drawer: const MyDrawer(),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _ActionButtonsRow(),
            SizedBox(height: 14),
            _DateDisplayRow(),
            SizedBox(height: 8),
            // NextPrayerCountdown(),
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

class _ActionButtonsRow extends StatelessWidget {
  const _ActionButtonsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _ActionButton(
            onPressed: () => _showManualCoordinatesDialog(context),
            label: 'إعدادات المواقيت',
            icon: Icons.settings,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            onPressed: () => _showHijriAdjustDialog(context),
            label: 'تعديل اليوم الهجرى',
            icon: Icons.date_range,
          ),
        ),
      ],
    );
  }

  void _showManualCoordinatesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => PrayerSettingsDialog(),
    );
  }

  void _showHijriAdjustDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AdjustHijriDayDialogbox(),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  const _ActionButton({
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      label: InlineTextWidget(label, textAlign: TextAlign.center),
      icon: Icon(icon),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _DateDisplayRow extends StatelessWidget {
  const _DateDisplayRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                // The redundant GetBuilder has been removed.
                // HijriDateWidget handles its own updates perfectly.
                child: const HijriDateWidget(),
              ),
            ),
          ),
        ),
        SizedBox(width: 6),
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(
                // Use our new, efficient Georgian Date widget.
                child: _GeorgianDateWidget(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GeorgianDateWidget extends StatefulWidget {
  const _GeorgianDateWidget();

  @override
  State<_GeorgianDateWidget> createState() => _GeorgianDateWidgetState();
}

class _GeorgianDateWidgetState extends State<_GeorgianDateWidget> {
  late DateTime _currentDate;
  Timer? _timer;

  static const Map<int, String> _arabicMonths = {
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

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
    _scheduleNextUpdate();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Important: prevent memory leaks
    super.dispose();
  }

  void _scheduleNextUpdate() {
    final now = DateTime.now();
    // Calculate the exact moment of the next midnight.
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = nextMidnight.difference(now);

    // Set a timer that will fire only once, precisely at midnight.
    _timer = Timer(durationUntilMidnight, () {
      if (mounted) {
        setState(() {
          _currentDate = DateTime.now();
        });
        // After updating, schedule the *next* update for the following midnight.
        _scheduleNextUpdate();
      }
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_arabicMonths[date.month]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return InlineTextWidget(
      style: Theme.of(context).textTheme.titleMedium,
      _formatDate(_currentDate),
      textDirection: TextDirection.rtl,
    );
  }
}

class ScaleSize {
  static double textScaleFactor(BuildContext context,
      {double maxTextScaleFactor = 2}) {
    final width = MediaQuery.of(context).size.width;
    double val = (width / 1400) * maxTextScaleFactor;
    return max(1, min(val, maxTextScaleFactor));
  }
}
