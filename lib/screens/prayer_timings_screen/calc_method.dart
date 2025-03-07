import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';

class CalcMethodDropDown extends StatefulWidget {
  const CalcMethodDropDown({super.key, required this.onSelect});
  final Function(String) onSelect;

  @override
  State<CalcMethodDropDown> createState() => _CalcMethodDropDownState();
}

class _CalcMethodDropDownState extends State<CalcMethodDropDown> {
  final arabicMethods = {
    CalculationMethod.egyptian: 'مصر',
    CalculationMethod.karachi: 'كراتشي',
    CalculationMethod.muslim_world_league: 'رابطة العالم الإسلامي',
    CalculationMethod.dubai: 'دبي',
    CalculationMethod.qatar: 'قطر',
    CalculationMethod.kuwait: 'الكويت',
    CalculationMethod.turkey: 'تركيا',
    CalculationMethod.tehran: 'طهران',
    CalculationMethod.singapore: 'سنغافورة',
    CalculationMethod.umm_al_qura: 'أم القري',
    CalculationMethod.north_america: 'أمريكا الشمالية',
    CalculationMethod.moon_sighting_committee: 'لجنة رؤية القمر',
    CalculationMethod.other: 'أخرى',
  };
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
      value: method,
      hint: Text(
        'طريقة الحساب',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      items: CalculationMethod.values.map((e) {
        return DropdownMenuItem(
          alignment: Alignment.centerRight,
          value: e.name,
          child: Text(
            arabicMethods[e]!,
            style: Theme.of(context).textTheme.titleSmall,
          ),
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
