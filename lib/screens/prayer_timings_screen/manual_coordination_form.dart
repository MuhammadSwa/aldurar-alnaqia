import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yosria/screens/prayer_timings_screen/asr_calc_segmented_button.dart';
import 'package:yosria/screens/prayer_timings_screen/calc_method.dart';
import 'package:yosria/screens/prayer_timings_screen/coordinates_text_input_widget.dart';
import 'package:yosria/screens/prayer_timings_screen/location_button_widget.dart';
import 'package:yosria/screens/prayer_timings_screen/prayerTimingsController.dart';

class ManualCoordinatesFormModel {
  double _latitude = 0.0;
  double _longitude = 0.0;
  String asrCalculation = 'shafi';
  String method = 'egyptian';

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

  final controller = <String, TextEditingController>{
    'latitude': TextEditingController(),
    'longitude': TextEditingController(),
  };

  final ManualCoordinatesFormModel _formModel = ManualCoordinatesFormModel();

  void _onSegmentedButtonSelected(String data) {
    _formModel.asrCalculation = data;
  }

  void onGettingLocation(
      {required String latitude, required String longitude}) {
    controller['latitude']!.text = latitude;
    controller['longitude']!.text = longitude;
    _formModel.setLatitude(latitude);
    _formModel.setLongitude(longitude);
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
                  Text(
                    'حدد الإحداثيات',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
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
                      controller: controller, formModel: _formModel),
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
                      if (_formKey.currentState!.validate()) {
                        // TODO: validate lat and long are 90 and -90, 180 and -180
                        final lat = _formModel.latitude;
                        final long = _formModel.longitude;
                        final method = _formModel.method;
                        final asrCalculation = _formModel.asrCalculation;
                        Get.put(PrayerTimingsController()).setPrayerSettings(
                          lat: lat,
                          long: long,
                          method: method,
                          asrCalc: asrCalculation,
                        );
                        Navigator.pop(context);
                        // pop if you make timings setting screen
                      }
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
