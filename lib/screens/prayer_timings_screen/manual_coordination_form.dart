import 'package:aldurar_alnaqia/screens/prayer_timings_screen/calculation_method_info.dart';
import 'package:aldurar_alnaqia/utils/showSnackbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/asr_calc_segmented_button.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/calc_method.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/coordinates_text_input_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/location_button_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';

class ManualCoordinatesFormModel {
  double _latitude = 0.0;
  double _longitude = 0.0;
  String asrCalculation = 'shafi';
  // String method = 'egyptian';

  String method = CalculationMethodInfo.methods.first.key;

  double get latitude => _latitude;
  double get longitude => _longitude;

  // the String is garanteed to be valid double because of TextFieldValidation
  void setLatitude(String value) {
    _latitude = double.parse(value);
  }

  void setLongitude(String value) {
    _longitude = double.parse(value);
  }
}

// CoordinatesForm
class ManualCoordinatesForm extends StatelessWidget {
  ManualCoordinatesForm({super.key});

  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  // String method = CalculationMethodInfo.methods.first.key;
  // String _selectedAsrCalc = 'shafi';

  final ManualCoordinatesFormModel _formModel = ManualCoordinatesFormModel();

  void _onSegmentedButtonSelected(String data) {
    _formModel.asrCalculation = data;
  }

  void onGettingLocation(
      {required String latitude, required String longitude}) {
    _latController.text = latitude;
    _lngController.text = longitude;
    _formModel.setLatitude(latitude);
    _formModel.setLongitude(longitude);
  }

  @override
  Widget build(BuildContext context) {
    void saveSettings() {
      if (!_formKey.currentState!.validate()) return;

      // _prayerController.updateSettings(
      //   latitude: double.parse(_latController.text),
      //   longitude: double.parse(_lngController.text),
      //   calculationMethod: _selectedMethod,
      //   asrCalculation: _selectedAsrCalc,
      // );
      //
      // Navigator.of(context).pop();
      // _showSuccessSnackbar();

      // TODO: validate lat and long are 90 and -90, 180 and -180
      final method = _formModel.method;
      final asrCalculation = _formModel.asrCalculation;
      Get.put(PrayerTimingsController()).setPrayerSettings(
        lat: double.parse(_latController.text),
        long: double.parse(_lngController.text),
        method: method,
        asrCalc: asrCalculation,
      );

      Navigator.of(context).pop();
      showSnackBar(context, 'تم حفظ إعدادات مواقيت الصلاة بنجاح');
    }

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
                // crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(
                    height: 10,
                  ),
                  LocationButtonWidget(
                    onGettingLocation: onGettingLocation,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  CoordinatesTextInputWidget(
                      latController: _latController,
                      lngController: _lngController,
                      formModel: _formModel),
                  const SizedBox(
                    height: 10,
                  ),
                  AsrCalcSegmentedButton(onData: _onSegmentedButtonSelected),
                  const SizedBox(
                    height: 10,
                  ),
                  CalcMethodDropDown(
                    onSelect: (value) => _formModel.method = value,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      saveSettings();
                    },
                    child: const Text('تأكيد'),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
