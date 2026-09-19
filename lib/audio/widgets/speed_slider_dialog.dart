import 'package:material_ui/material_ui.dart';

void showSliderDialog({
  required BuildContext context,
  required String title,
  required int divisions,
  required double min,
  required double max,
  String valueSuffix = '',
  required double value,
  required ValueChanged<double> onChanged,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: StatefulBuilder(
        builder: (context, setState) => SizedBox(
          height: 100.0,
          child: Column(
            children: [
              Text(
                '$value$valueSuffix',
                style: const TextStyle(
                  fontFamily: 'Fixed',
                  fontWeight: FontWeight.bold,
                  fontSize: 24.0,
                ),
              ),
              Slider(
                divisions: divisions,
                min: min,
                max: max,
                value: value,
                onChanged: (newValue) => setState(() => value = newValue),
                onChangeEnd: onChanged,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
