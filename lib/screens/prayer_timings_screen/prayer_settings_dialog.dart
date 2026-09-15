import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/calculation_method_info.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/utils/show_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/asr_calc_segmented_button.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/calc_method.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/city_picker.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/location_button_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart'
    show prayerProvider;

// Prayer settings dialog: GPS or city-picker location + madhab + method.
class PrayerSettingsDialog extends ConsumerStatefulWidget {
  const PrayerSettingsDialog({super.key});

  @override
  ConsumerState<PrayerSettingsDialog> createState() =>
      _PrayerSettingsDialogState();
}

class _PrayerSettingsDialogState extends ConsumerState<PrayerSettingsDialog> {
  late String _selectedAsrCalc;
  late String _selectedMethod;

  /// Location chosen via GPS or the city picker (manual entry removed).
  double? _latitude;
  double? _longitude;
  City? _selectedCity;

  /// True when the user located via GPS rather than picking a city.
  bool _isGpsLocation = false;

  /// Inline validation flag: shown as red text under the location section.
  bool _showLocationError = false;

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
    // Location always starts cleared: the user picks a city or GPS fresh
    // on every open (no restore of the previously saved location).
  }

  void _onCitySelected(City city) {
    setState(() {
      _selectedCity = city;
      _latitude = city.latitude;
      _longitude = city.longitude;
      _isGpsLocation = false;
      _showLocationError = false;
    });
  }

  void onGettingLocation(
      {required String latitude, required String longitude}) {
    final lat = double.tryParse(latitude);
    final lng = double.tryParse(longitude);
    if (lat == null || lng == null) return;
    if (mounted) {
      setState(() {
        _latitude = lat;
        _longitude = lng;
        _selectedCity = null;
        _isGpsLocation = true;
        _showLocationError = false;
      });
    }
  }

  bool get _hasLocation => _latitude != null && _longitude != null;

  void _saveSettings(BuildContext context) {
    if (!_hasLocation) {
      if (mounted) setState(() => _showLocationError = true);
      return;
    }

    ref.read(prayerProvider.notifier).setPrayerSettings(
          lat: _latitude!,
          long: _longitude!,
          method: _selectedMethod,
          asrCalc: _selectedAsrCalc,
          city: _isGpsLocation ? null : _selectedCity,
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings, color: theme.colorScheme.primary),
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
                CityPickerField(
                  selected: _selectedCity,
                  onSelected: _onCitySelected,
                ),
                const SizedBox(height: 8),
                LocationButtonWidget(
                    onGettingLocation: onGettingLocation,
                    hasLocation: _hasLocation && _isGpsLocation),
                if (_showLocationError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'برجاء تحديد الموقع أولاً',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                ActionButtons(onPress: () => _saveSettings(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSegmentedButtonSelected(String data) {
    _selectedAsrCalc = data;
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
