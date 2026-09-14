import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/calculation_method_info.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
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
  late String _selectedAsrCalc;
  late String _selectedMethod;

  /// Manual lat/lng fields are hidden until the user asks for them.
  bool _showManual = false;

  @override
  void initState() {
    super.initState();
    _selectedAsrCalc = SharedPreferencesService.getAsrCalculation();
    if (_selectedAsrCalc != 'shafi' && _selectedAsrCalc != 'hanafi') {
      _selectedAsrCalc = 'shafi';
    }
    _selectedMethod = SharedPreferencesService.getMethod();
    if (!CalculationMethodInfo.methods.any((m) => m.key == _selectedMethod)) {
      _selectedMethod = CalculationMethodInfo.methods.first.key;
    }
    final lat = SharedPreferencesService.getLatitude();
    final lng = SharedPreferencesService.getLongitude();
    if (lat != 0.0 && lng != 0.0) {
      _latController.text = lat.toString();
      _lngController.text = lng.toString();
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _onSegmentedButtonSelected(String data) {
    _selectedAsrCalc = data;
  }

  void onGettingLocation(
      {required String latitude, required String longitude}) {
    _latController.text = latitude;
    _lngController.text = longitude;
    if (mounted) setState(() => _showManual = false);
  }

  bool get _hasLocation =>
      _latController.text.trim().isNotEmpty &&
      _lngController.text.trim().isNotEmpty;

  void _saveSettings(BuildContext context) {
    if (!_formKey.currentState!.validate()) {
      // If validation fails because of empty coords, reveal the manual
      // fields so the user can see what needs fixing.
      if (!_hasLocation && mounted) setState(() => _showManual = true);
      return;
    }

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
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'إعدادات المواقيت',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ---- 1. Location ----
                  Text(
                    'الموقع',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LocationButtonWidget(
                      onGettingLocation: onGettingLocation,
                      hasLocation: _hasLocation),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: () => setState(
                          () => _showManual = !_showManual),
                      icon: Icon(_showManual
                          ? Icons.expand_less
                          : Icons.edit_location_alt_outlined),
                      label: Text(_showManual
                          ? 'إخفاء الإدخال اليدوي'
                          : 'إدخال يدوي'),
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: CoordinatesTextInputWidget(
                        latController: _latController,
                        lngController: _lngController,
                      ),
                    ),
                    crossFadeState: _showManual
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),

                  const Divider(height: 24),

                  // ---- 2. Asr madhab ----
                  AsrCalcSegmentedButton(
                    initial: _selectedAsrCalc,
                    onData: _onSegmentedButtonSelected,
                  ),

                  const Divider(height: 24),

                  // ---- 3. Calculation method ----
                  CalcMethodDropDown(
                    initialMethod: _selectedMethod,
                    onSelect: (value) => _selectedMethod = value,
                  ),
                  const SizedBox(height: 20),
                  ActionButtons(
                      onPress: () => _saveSettings(context)),
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
