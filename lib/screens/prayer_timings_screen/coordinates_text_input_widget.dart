import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CoordinatesTextInputWidget extends StatelessWidget {
  const CoordinatesTextInputWidget({
    super.key,
    required this.latController,
    required this.lngController,
  });

  // final Map<String, TextEditingController> controller;

  final TextEditingController latController;
  final TextEditingController lngController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildCoordinateField(
            controller: latController,
            label: 'خط العرض',
            hint: 'مثال: 30.0444',
            validator: _validateLatitude,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCoordinateField(
            controller: lngController,
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

  String? _validateLatitude(String? value) {
    if (value == null || value.isEmpty) {
      return 'برجاء إدخال خط العرض';
    }

    final lat = double.tryParse(value);
    if (lat == null) {
      return 'برجاء إدخال رقم صحيح';
    }

    if (lat < -90 || lat > 90) {
      return 'بين -90 و 90';
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
      return 'بين -180 و 180';
    }

    return null;
  }
}
