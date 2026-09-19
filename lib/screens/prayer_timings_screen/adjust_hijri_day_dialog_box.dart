import 'package:aldurar_alnaqia/screens/prayer_timings_screen/hijri_adjust_form.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Today's Hijri date dialog (day-offset adjustment form).
class AdjustHijriDayDialogbox extends ConsumerWidget {
  const AdjustHijriDayDialogbox({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AlertDialog(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      content: HijriAdjustForm(showCancel: true),
    );
  }
}
