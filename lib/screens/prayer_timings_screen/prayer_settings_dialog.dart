// widgets/prayer_settings_dialog.dart
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/calculation_method_info.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/location_service.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class PrayerSettingsDialog extends StatefulWidget {
  const PrayerSettingsDialog({super.key});

  @override
  State<PrayerSettingsDialog> createState() => _PrayerSettingsDialogState();
}

class _PrayerSettingsDialogState extends State<PrayerSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  String _selectedMethod = CalculationMethodInfo.methods.isNotEmpty
      ? CalculationMethodInfo.methods.first.key
      : 'egyptian'; // Default if list is empty
  String _selectedAsrCalc = 'shafi';
  bool _isLoadingLocation = false;

  final PrayerController _prayerController = Get.find<PrayerController>();

  // final PrayerController _prayerController = Get.put(PrayerController());

  @override
  void initState() {
    super.initState();
    // Load existing settings if available
    if (_prayerController.isConfigured &&
        _prayerController.prayerSettings != null) {
      final settings = _prayerController.prayerSettings!;
      _latController.text = settings.latitude.toString();
      _lngController.text = settings.longitude.toString();
      _selectedMethod = settings.calculationMethod;
      _selectedAsrCalc = settings.asrCalculation;

      // Ensure _selectedMethod is valid
      if (!CalculationMethodInfo.methods.any((m) => m.key == _selectedMethod)) {
        _selectedMethod = CalculationMethodInfo.methods.isNotEmpty
            ? CalculationMethodInfo.methods.first.key
            : 'egyptian';
      }
    } else if (CalculationMethodInfo.methods.isNotEmpty) {
      _selectedMethod = CalculationMethodInfo.methods.first.key;
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'إعدادات مواقيت الصلاة',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _buildLocationButton(),
                  const SizedBox(height: 16),
                  _buildCoordinatesInput(),
                  const SizedBox(height: 16),
                  _buildCalculationMethodDropdown(),
                  const SizedBox(height: 16),
                  _buildAsrCalculationSegments(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    return ElevatedButton.icon(
      onPressed: _isLoadingLocation ? null : _getCurrentLocation,
      icon: _isLoadingLocation
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.location_on),
      label: const Text('تحديد الموقع تلقائياً'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildCoordinatesInput() {
    return Row(
      children: [
        Expanded(
          child: _buildCoordinateField(
            controller: _latController,
            label: 'خط العرض',
            hint: 'مثال: 30.0444',
            validator: _validateLatitude,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCoordinateField(
            controller: _lngController,
            label: 'خط الطول',
            hint: 'مثال: 31.2357',
            validator: _validateLongitude,
          ),
        ),
      ],
    );
  }

  Widget _buildCoordinateField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.location_on),
      ),
    );
  }

  Widget _buildCalculationMethodDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedMethod,
      isExpanded: true, // Helps with long text items
      decoration: const InputDecoration(
        labelText: 'طريقة الحساب',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.calculate),
      ),
      items: CalculationMethodInfo.methods.map((method) {
        return DropdownMenuItem(
          value: method.key,
          child: Text(method.arabicName, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedMethod = value);
        }
      },
      validator: (value) =>
          value == null || value.isEmpty ? 'برجاء اختيار طريقة الحساب' : null,
    );
  }

  Widget _buildAsrCalculationSegments() {
    return Column(
      children: [
        Text(
          'حساب وقت العصر',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'hanafi', label: Text('الحنفي')),
            ButtonSegment(value: 'shafi', label: Text('الشافعي')),
          ],
          selected: {_selectedAsrCalc},
          onSelectionChanged: (selection) {
            setState(() => _selectedAsrCalc = selection.first);
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
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
            onPressed: _saveSettings,
            child: const Text('حفظ'),
          ),
        ),
      ],
    );
  }

  void _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Assuming LocationService is correctly implemented or stubbed
      final position = await LocationService.getCurrentPosition();
      _latController.text = position.latitude.toString();
      _lngController.text = position.longitude.toString();
    } catch (e) {
      if (mounted) {
        // Check if the widget is still in the tree
        _showErrorDialog('خطأ في تحديد الموقع',
            'تعذر الحصول على الموقع الحالي: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _saveSettings() {
    if (!_formKey.currentState!.validate()) return;

    _prayerController.updateSettings(
      latitude: double.parse(_latController.text),
      longitude: double.parse(_lngController.text),
      calculationMethod: _selectedMethod,
      asrCalculation: _selectedAsrCalc,
    );

    Navigator.of(context).pop();
    _showSuccessSnackbar();
  }

  String? _validateLatitude(String? value) {
    if (value == null || value.isEmpty) {
      return 'برجاء إدخال خط العرض';
    }

    final lat = double.tryParse(value);
    if (lat == null) {
      return 'برجاء إدخال رقم صحيح';
    }

    if (lat < -90 || lat > 90) {
      return 'خط العرض يجب أن يكون بين -90 و 90';
    }

    return null;
  }

  String? _validateLongitude(String? value) {
    if (value == null || value.isEmpty) {
      return 'برجاء إدخال خط الطول';
    }

    final lng = double.tryParse(value);
    if (lng == null) {
      return 'برجاء إدخال رقم صحيح';
    }

    if (lng < -180 || lng > 180) {
      return 'خط الطول يجب أن يكون بين -180 و 180';
    }

    return null;
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(milliseconds: 700),
        content: Text('تم حفظ إعدادات مواقيت الصلاة بنجاح'),
      ),
    );

    // Get.snackbar(
    //   'تم الحفظ',
    //   'تم حفظ إعدادات مواقيت الصلاة بنجاح',
    //   snackPosition: SnackPosition.BOTTOM,
    //   backgroundColor: Colors.green.shade100,
    //   colorText: Colors.green.shade800,
    // );
  }
}
