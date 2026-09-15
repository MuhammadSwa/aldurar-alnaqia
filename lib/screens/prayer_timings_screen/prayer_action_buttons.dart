import 'package:aldurar_alnaqia/common/widgets/inline_text.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/adjust_hijri_day_dialog_box.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_settings_dialog.dart';
import 'package:flutter/material.dart';

class PrayerActionButtonsRow extends StatelessWidget {
  const PrayerActionButtonsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: PrayerActionButton(
            onPressed: () => _showManualCoordinatesDialog(context),
            label: 'إعدادات المواقيت',
            icon: Icons.settings,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PrayerActionButton(
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
      builder: (context) => const PrayerSettingsDialog(),
    );
  }

  void _showHijriAdjustDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AdjustHijriDayDialogbox(),
    );
  }
}

class PrayerActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  const PrayerActionButton({
    super.key,
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
