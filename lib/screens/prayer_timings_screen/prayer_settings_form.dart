import 'package:aldurar_alnaqia/common/helpers/snackbar.dart';
import 'package:aldurar_alnaqia/prayer/prayer_providers.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/asr_calc_segmented_button.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/calc_method.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/city_directory.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/city_picker.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/location_button_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/location_timezone.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/calculation_method_info.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/city.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_settings_dialog.dart' show PrayerSettingsDialog;
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Reusable prayer-settings editor (location + madhab + method).
///
/// Used inline by the settings page and wrapped in a [Dialog] by
/// [PrayerSettingsDialog] (kept for the auto-setup prompt and other callers).
class PrayerSettingsForm extends ConsumerStatefulWidget {

  const PrayerSettingsForm({super.key, this.showCancel = true, this.onSaved});
  /// When true (dialog use) a cancel button is shown next to save.
  final bool showCancel;
  final VoidCallback? onSaved;

  @override
  ConsumerState<PrayerSettingsForm> createState() => _PrayerSettingsFormState();
}

class _PrayerSettingsFormState extends ConsumerState<PrayerSettingsForm> {
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
    // Warm the city directory while the user reads, so the city search
    // sheet opens instantly.
    ref.read(cityDirectoryProvider);
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

  Future<void> onGettingLocation({
    required String latitude,
    required String longitude,
  }) async {
    final lat = double.tryParse(latitude);
    final lng = double.tryParse(longitude);
    if (lat == null || lng == null) return;
    final directory = await ref.read(cityDirectoryProvider.future);
    final nearest = LocationTimezone.nearestCity(
      latitude: lat,
      longitude: lng,
      cities: directory.cities,
    );
    if (!mounted) return;
    setState(() {
      _latitude = lat;
      _longitude = lng;
      // Populate the city search field with the nearest city instead of
      // showing it as a separate line below the button. Exact GPS
      // coordinates are still used for the calculation; null when remote
      // (no city within 50 km) so the coordinates note below still shows.
      _selectedCity = nearest;
      _isGpsLocation = true;
      _showLocationError = false;
    });
  }

  bool get _hasLocation => _latitude != null && _longitude != null;

  Future<void> _saveSettings() async {
    if (!_hasLocation) {
      if (mounted) setState(() => _showLocationError = true);
      return;
    }

    final saved = await savePrayerSettings(
      ref,
      lat: _latitude!,
      long: _longitude!,
      method: _selectedMethod,
      asrCalc: _selectedAsrCalc,
      city: _isGpsLocation ? null : _selectedCity,
    );

    if (!mounted) return;
    if (saved) {
      showSnackBar(context, 'تم حفظ إعدادات مواقيت الصلاة بنجاح');
      widget.onSaved?.call();
    } else {
      showSnackBar(context, 'تعذّر تحديد المنطقة الزمنية للموقع');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          hasLocation: _hasLocation && _isGpsLocation,
        ),
        if (_isGpsLocation && _selectedCity == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'لا توجد مدينة قريبة — سيُعرض موقعك بالإحداثيات',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ),
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
          onData: (data) => _selectedAsrCalc = data,
        ),

        const Divider(height: 24),

        // ---- 3. Calculation method ----
        CalcMethodDropDown(
          initialMethod: _selectedMethod,
          onSelect: (value) => _selectedMethod = value,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            if (widget.showCancel) ...[
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _saveSettings,
                child: const Text('حفظ'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
