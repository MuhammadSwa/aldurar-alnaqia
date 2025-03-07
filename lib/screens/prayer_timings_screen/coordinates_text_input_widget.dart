import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yosria/screens/prayer_timings_screen/manual_coordination_form.dart';

// TODO: extract validation, make TextFormField it's own widget?
class CoordinatesTextInputWidget extends StatelessWidget {
  const CoordinatesTextInputWidget(
      {super.key, required this.controller, required this.formModel});

  final Map<String, TextEditingController> controller;
  final ManualCoordinatesFormModel formModel;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
      child: Row(
        children: [
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: TextFormField(
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'برجاء إدخال خط العرض';
                }

                if (double.tryParse(value) == null) {
                  return 'برجاء ادخال رقم';
                }
                if (double.parse(value) > 180 || double.parse(value) < -180) {
                  return 'يجب ان يكون خط العرض بين 90 و -90';
                }
                return null;
              },
              onChanged: (value) => formModel.setLatitude(value),
              controller: controller['latitude'],
              decoration: const InputDecoration(
                labelText: 'العرض',
                helperText: 'مثال: 30.0',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  signed: true, decimal: true),
              inputFormatters: [
                // only allow negative or positive doubles.
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                // FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,8}')),
              ],
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: TextFormField(
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'برجاء إدخال خط الطول';
                }
                if (double.tryParse(value) == null) {
                  return 'برجاء ادخال رقم';
                }
                if (double.parse(value) > 180 || double.parse(value) < -180) {
                  return 'يجب ان يكون خط الطول بين -180 و 180';
                }
                return null;
              },
              onChanged: (value) => formModel.setLongitude(value),
              controller: controller['longitude'],
              decoration: const InputDecoration(
                labelText: 'الطول',
                helperText: 'مثال: 30.0',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  signed: true, decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
              ],
            ),
          ),
          const SizedBox(
            width: 10,
          ),
        ],
      ),
    );
  }
}
