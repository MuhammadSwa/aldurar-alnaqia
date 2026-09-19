import 'package:aldurar_alnaqia/common/helpers/snackbar.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/adjust_hijri_day_dialog_box.dart' show AdjustHijriDayDialogbox;
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Reusable Hijri-day offset editor.
///
/// Used by the settings page inline and by [AdjustHijriDayDialogbox].
/// Saves immediately on selection — no save button.
/// When [showCancel] is true (dialog use) a close button is shown below.
class HijriAdjustForm extends ConsumerStatefulWidget {

  const HijriAdjustForm({super.key, this.showCancel = false});
  final bool showCancel;

  @override
  ConsumerState<HijriAdjustForm> createState() => _HijriAdjustFormState();
}

class _HijriAdjustFormState extends ConsumerState<HijriAdjustForm> {
  void _select(int offset) {
    if (ref.read(hijriOffsetProvider) == offset) return;
    ref.read(hijriOffsetProvider.notifier).set(offset);
    if (mounted) {
      showSnackBar(context, 'تم تعديل اليوم الهجري بنجاح.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedOffset = ref.watch(hijriOffsetProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'التعديل الحالي: ${selectedOffset > 0 ? '+' : ''}$selectedOffset يوم',
          textAlign: TextAlign.center,
        ),
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
          selected: <int>{selectedOffset},
          onSelectionChanged: (newSelection) {
            _select(newSelection.first);
          },
        ),
        if (widget.showCancel) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ],
    );
  }
}
