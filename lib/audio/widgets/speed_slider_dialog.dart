
import 'package:material_ui/material_ui.dart';

void showSliderDialog({
  required BuildContext context,
  required String title,
  required int divisions,
  required double min,
  required double max,
  required double value,
  required ValueChanged<double> onChanged,
  String valueSuffix = '',
}) {
  var currentValue = value;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: StatefulBuilder(
        builder: (context, setState) => SizedBox(
          height: 100,
          child: Column(
            children: [
              Text(
                '$currentValue$valueSuffix',
                style: const TextStyle(
                  fontFamily: 'Fixed',
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              Slider(
                divisions: divisions,
                min: min,
                max: max,
                value: currentValue,
                onChanged: (newValue) =>
                    setState(() => currentValue = newValue),
                onChangeEnd: onChanged,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
