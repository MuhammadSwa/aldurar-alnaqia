// prayer_timings_screen_refactored.dart
import 'package:aldurar_alnaqia/MyDrawer.dart'; // Assuming this exists
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/prayer_timeData.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_controller.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_settings_dialog-ai.dart';
import 'package:aldurar_alnaqia/utils/showSnackbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
// import 'package:aldurar_alnaqia/widgets/main_wrapper.dart'; // Assuming GlobalDrawerController is from here or similar

// If GlobalDrawerController is used, ensure it's available.
// For this refactor, I'll comment it out if not directly provided in the new structure.
// class GlobalDrawerController extends GetxController {
//   final _scaffoldKeys = <GlobalKey<ScaffoldState>>[].obs;
//   void registerScaffoldKey(GlobalKey<ScaffoldState> key) {
//     if (!_scaffoldKeys.contains(key)) {
//       _scaffoldKeys.add(key);
//     }
//   }
//   // Add methods to open/close drawer if needed, e.g.:
//   // void openDrawer() => _scaffoldKeys.firstOrNull?.currentState?.openDrawer();
// }

class PrayerTimingsScreen extends StatelessWidget {
  const PrayerTimingsScreen({super.key});

  static final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    // Initialize the new PrayerController
    Get.put(
        PrayerController()); // Use put instead of lazyPut if needed immediately

    // Get.lazyPut(() => GlobalDrawerController()); // Assuming this setup
    // final drawerController = Get.find<GlobalDrawerController>();
    // drawerController.registerScaffoldKey(_scaffoldKey);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          // onPressed: () => drawerController.openDrawer(), // Or _scaffoldKey.currentState?.openDrawer(),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'فتح القائمة',
        ),
      ),
      drawer: const MyDrawer(), // Assuming MyDrawer is defined
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _ActionButtonsRowRefactored(),
            SizedBox(height: 20),
            _DateDisplayRowRefactored(),
            SizedBox(height: 20),
            _NextPrayerCardRefactored(),
            SizedBox(height: 20),
            _PrayerTimingsCardRefactored(),
          ],
        ),
      ),
    );
  }
}

class _ActionButtonsRowRefactored extends StatelessWidget {
  const _ActionButtonsRowRefactored();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _ActionButton(
            onPressed: () => Get.dialog(const PrayerSettingsDialog()),
            label: 'إعدادات المواقيت',
            icon: Icons.settings,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            onPressed: () => Get.dialog(const AdjustHijriDayDialogRefactored()),
            label: 'تعديل اليوم الهجرى',
            icon: Icons.date_range,
          ),
        ),
      ],
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
      label:
          Text(label, textAlign: TextAlign.center), // Replaced InlineTextWidget
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

class _DateDisplayRowRefactored extends StatelessWidget {
  const _DateDisplayRowRefactored();

  @override
  Widget build(BuildContext context) {
    final PrayerController prayerController = Get.find<PrayerController>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: Obx(() => Text(
                      prayerController
                          .formatGeorgianDate(prayerController.currentTime),
                      style: Theme.of(context).textTheme.titleMedium,
                      textDirection: TextDirection.rtl,
                    )),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: Obx(() => Text(
                      prayerController
                          .formatHijriDate(prayerController.currentHijriDate),
                      style: Theme.of(context).textTheme.titleMedium,
                      textDirection: TextDirection.rtl,
                    )),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NextPrayerCardRefactored extends StatelessWidget {
  const _NextPrayerCardRefactored();

  @override
  Widget build(BuildContext context) {
    final PrayerController prayerController = Get.find<PrayerController>();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Obx(() {
          if (!prayerController.isConfigured ||
              prayerController.nextPrayerInfo == null) {
            return const Text(
              'برجاء تحديد الموقع وإعدادات الحساب أولاً',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            );
          }

          final nextPrayer = prayerController.nextPrayerInfo!;
          return Column(
            children: [
              Text(
                nextPrayer.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'بعد ${prayerController.formatDuration(nextPrayer.timeRemaining)}',
                style: Theme.of(context).textTheme.titleMedium,
                textDirection:
                    TextDirection.rtl, // Ensure RTL for duration string
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _PrayerTimingsCardRefactored extends StatelessWidget {
  const _PrayerTimingsCardRefactored();

  @override
  Widget build(BuildContext context) {
    final PrayerController prayerController = Get.find<PrayerController>();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Obx(() {
          if (!prayerController.isConfigured ||
              prayerController.allPrayerTimes.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'برجاء تحديد الموقع وإعدادات الحساب لعرض المواقيت',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final prayers = prayerController.allPrayerTimes;

          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(
                    1.2), // Adjusted for potentially longer formatted time
              },
              children: prayers
                  .map((prayerData) =>
                      _buildTableRow(context, prayerData, prayerController))
                  .toList(),
            ),
          );
        }),
      ),
    );
  }

  TableRow _buildTableRow(BuildContext context, PrayerTimeData prayerData,
      PrayerController controller) {
    // Highlight main prayers differently, or add an icon, or based on prayerData.isMainPrayer
    // For now, just using the name and time.
    final bool isNextPrayer =
        controller.nextPrayerInfo?.nextPrayerTime == prayerData.time;
    final Color? rowColor = isNextPrayer
        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
        : null;
    final FontWeight fontWeight =
        prayerData.isMainPrayer ? FontWeight.bold : FontWeight.normal;

    return TableRow(
      decoration: BoxDecoration(
        color: rowColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Text(
            prayerData.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: fontWeight, // Use fontWeight based on isMainPrayer
            ),
            textAlign: TextAlign.right,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Text(
            controller.formatTime(prayerData.time),
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'monospace', // Keep monospace for time
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr, // Time is LTR
          ),
        ),
      ],
    );
  }
}

class AdjustHijriDayDialogRefactored extends StatefulWidget {
  const AdjustHijriDayDialogRefactored({super.key});

  @override
  State<AdjustHijriDayDialogRefactored> createState() =>
      _AdjustHijriDayDialogRefactoredState();
}

class _AdjustHijriDayDialogRefactoredState
    extends State<AdjustHijriDayDialogRefactored> {
  late int _selectedOffset;
  final PrayerController prayerController = Get.find<PrayerController>();
  // final PrayerController prayerController = Get.put(PrayerController());

  @override
  void initState() {
    super.initState();
    _selectedOffset = prayerController.hijriOffset;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل اليوم الهجري', textAlign: TextAlign.center),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              'التعديل الحالي: ${_selectedOffset > 0 ? '+' : ''}$_selectedOffset يوم',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<int>(value: -2, label: Text('-2')),
              ButtonSegment<int>(value: -1, label: Text('-1')),
              ButtonSegment<int>(value: 0, label: Text('0')),
              ButtonSegment<int>(value: 1, label: Text('+1')),
              ButtonSegment<int>(value: 2, label: Text('+2')),
            ],
            selected: <int>{_selectedOffset},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() {
                _selectedOffset = newSelection.first;
              });
            },
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            prayerController.updateHijriOffset(_selectedOffset);
            Navigator.of(context).pop();

            showSnackBar(context, 'تم تعديل اليوم الهجري بنجاح.');
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
