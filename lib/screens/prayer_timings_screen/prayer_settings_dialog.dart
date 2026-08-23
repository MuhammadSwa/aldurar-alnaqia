import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/calculation_method_info.dart';
import 'package:aldurar_alnaqia/utils/show_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/asr_calc_segmented_button.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/calc_method.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/coordinates_text_input_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/location_button_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart'
    show prayerProvider;

// CoordinatesForm
class PrayerSettingsDialog extends ConsumerStatefulWidget {
  const PrayerSettingsDialog({super.key});

  @override
  ConsumerState<PrayerSettingsDialog> createState() =>
      _PrayerSettingsDialogState();
}

class _PrayerSettingsDialogState extends ConsumerState<PrayerSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  String _selectedAsrCalc = 'shafi';
  String _selectedMethod = CalculationMethodInfo.methods.first.key;

  void _onSegmentedButtonSelected(String data) {
    _selectedAsrCalc = data;
  }

  void onGettingLocation({required String latitude, required String longitude}) {
    _latController.text = latitude;
    _lngController.text = longitude;
  }

  void _saveSettings(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;

    ref.read(prayerProvider.notifier).setPrayerSettings(
          lat: double.parse(_latController.text),
          long: double.parse(_lngController.text),
          method: _selectedMethod,
          asrCalc: _selectedAsrCalc,
        );

    Navigator.of(context).pop();
    showSnackBar(context, 'تم حفظ إعدادات مواقيت الصلاة بنجاح');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  LocationButtonWidget(onGettingLocation: onGettingLocation),
                  const SizedBox(height: 16),
                  CoordinatesTextInputWidget(
                    latController: _latController,
                    lngController: _lngController,
                  ),
                  const SizedBox(height: 16),
                  AsrCalcSegmentedButton(onData: _onSegmentedButtonSelected),
                  const SizedBox(height: 16),
                  CalcMethodDropDown(onSelect: (value) => _selectedMethod = value),
                  const SizedBox(height: 24),
                  ActionButtons(onPress: () => _saveSettings(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ActionButtons extends StatelessWidget {
  const ActionButtons({super.key, required this.onPress});

  final void Function() onPress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onPress,
            child: const Text('حفظ'),
          ),
        ),
      ],
    );
  }
}
