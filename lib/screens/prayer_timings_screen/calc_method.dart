import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/calculation_method_info.dart';
import 'package:flutter/material.dart';

class CalcMethodDropDown extends StatefulWidget {
  const CalcMethodDropDown({
    super.key,
    required this.onSelect,
    this.initialMethod,
  });
  final Function(String) onSelect;

  /// Previously saved method key — pre-selects it instead of starting empty.
  final String? initialMethod;

  @override
  State<CalcMethodDropDown> createState() => _CalcMethodDropDownState();
}

class _CalcMethodDropDownState extends State<CalcMethodDropDown> {
  String? method;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMethod;
    if (initial != null &&
        CalculationMethodInfo.methods.any((m) => m.key == initial)) {
      method = initial;
      // Report the pre-selected value so saving without touching
      // the dropdown still keeps the saved method.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSelect(initial);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField(
      validator: (value) {
        if (value == null) {
          return 'برجاء اختيار طريقة الحساب';
        }
        return null;
      },
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'طريقة الحساب',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.calculate),
      ),
      initialValue: method,
      hint: Text(
        'طريقة الحساب',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      items: CalculationMethodInfo.methods.map((method) {
        return DropdownMenuItem(
          value: method.key,
          child: Text(method.arabicName,
              maxLines: 2, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          method = value;
        });
        if (value != null) {
          widget.onSelect(value);
        }
      },
    );
  }
}
