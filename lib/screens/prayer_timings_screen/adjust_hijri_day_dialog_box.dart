import 'package:aldurar_alnaqia/utils/show_snackbar.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart';

/// Returns today's Hijri date adjusted by [offset] days, taking the
/// Maghrib-based Islamic day boundary into account when prayer times exist.
HijriCalendar? hijriDayWithOffset(int offset) {
  HijriCalendar.setLocal('ar');
  final adjustedDate = DateTime.now().add(Duration(days: offset));

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

class AdjustHijriDayDialogbox extends ConsumerStatefulWidget {
  const AdjustHijriDayDialogbox({super.key});

  @override
  ConsumerState<AdjustHijriDayDialogbox> createState() =>
      _AdjustHijriDayDialogboxState();
}

class _AdjustHijriDayDialogboxState
    extends ConsumerState<AdjustHijriDayDialogbox> {
  late int _selectedOffset = ref.read(hijriOffsetProvider);

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
              ref.read(hijriOffsetProvider.notifier).set(_selectedOffset);
              Navigator.of(context).pop();

              showSnackBar(context, 'تم تعديل اليوم الهجري بنجاح.');
            },
            child: const Text('حفظ'),
          ),
        ]);
  }
}
