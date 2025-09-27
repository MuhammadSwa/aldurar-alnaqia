import 'package:aldurar_alnaqia/utils/showSnackbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/instance_manager.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';

class AdjustHijriDayDialogbox extends StatefulWidget {
  const AdjustHijriDayDialogbox({super.key});

  @override
  State<AdjustHijriDayDialogbox> createState() =>
      _AdjustHijriDayDialogboxState();
}

class _AdjustHijriDayDialogboxState extends State<AdjustHijriDayDialogbox> {
  final hc = Get.put(HijriOffsetController());

  var _selectedOffset = Get.put(HijriOffsetController()).offset.value;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
              hc.setHiJriDayOffset(_selectedOffset);
              Navigator.of(context).pop();

              showSnackBar(context, 'تم تعديل اليوم الهجري بنجاح.');
            },
            child: const Text('حفظ'),
          ),
        ]);
  }
}

class HijriOffsetController extends GetxController {
  var offset = SharedPreferencesService.getHijriDayOffset().obs;

  HijriCalendar? getHijriDayByoffest() {
    HijriCalendar.setLocal('ar');
    final adjustedDate = DateTime.now().add(Duration(days: offset.value));

    final now = DateTime.now();
    final maghrib = PrayerTimeings.getPrayersTimings()?.maghrib;
    if (maghrib == null) {
      // when timings aren't set, return hijriday without considering maghrib,
      return HijriCalendar.fromDate(adjustedDate);
    }

// if maghrib timing available return hijriday considering maghrib
    if (now.isAfter(maghrib)) {
      return HijriCalendar.fromDate(adjustedDate.add(const Duration(days: 1)));
    }

    return HijriCalendar.fromDate(adjustedDate);
  }

  HijriCalendar nextDayHijriDay() {
    HijriCalendar.setLocal('ar');
    final adjustedDate = DateTime.now().add(Duration(days: offset.value + 1));
    return HijriCalendar.fromDate(adjustedDate);
  }

  setHiJriDayOffset(int i) {
    offset.value = i;
    SharedPreferencesService.setHijriDayOffset(i);
    update();
  }
}
