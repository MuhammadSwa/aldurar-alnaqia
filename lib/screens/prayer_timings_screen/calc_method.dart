import 'package:aldurar_alnaqia/screens/prayer_timings_screen/models/calculation_method_info.dart';
import 'package:flutter/material.dart';

class CalcMethodDropDown extends StatefulWidget {
  const CalcMethodDropDown({super.key, required this.onSelect});
  final Function(String) onSelect;

  @override
  State<CalcMethodDropDown> createState() => _CalcMethodDropDownState();
}

class _CalcMethodDropDownState extends State<CalcMethodDropDown> {
  String? method;
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
      value: method,
      hint: Text(
        'طريقة الحساب',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      items: CalculationMethodInfo.methods.map((method) {
        return DropdownMenuItem(
          value: method.key,
          child: Text(method.arabicName, overflow: TextOverflow.ellipsis),
        );
      }).toList(),

      // items: CalculationMethod.values.map((e) {
      //   return DropdownMenuItem(
      //     alignment: Alignment.centerRight,
      //     value: e.name,
      //     child: Text(
      //       arabicMethods[e]!,
      //       style: Theme.of(context).textTheme.titleSmall,
      //     ),
      //   );
      // }).toList(),
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
