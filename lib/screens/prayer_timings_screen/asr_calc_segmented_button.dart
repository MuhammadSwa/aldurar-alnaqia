
import 'package:flutter/material.dart';

enum AsrCalculation { shafi, hanafi }

class AsrCalcSegmentedButton extends StatefulWidget {
  const AsrCalcSegmentedButton({super.key, required this.onData});
  final void Function(String) onData;

  @override
  State<AsrCalcSegmentedButton> createState() => _AsrCalculationWidget();
}

class _AsrCalculationWidget extends State<AsrCalcSegmentedButton> {
  AsrCalculation method = AsrCalculation.shafi;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          "حساب وقت العصر على المذهب",
          textAlign: TextAlign.center,
        ),
        SegmentedButton<AsrCalculation>(
          segments: const [
            ButtonSegment<AsrCalculation>(
              value: AsrCalculation.hanafi,
              label: Text('الحنفي'),
            ),
            ButtonSegment<AsrCalculation>(
              value: AsrCalculation.shafi,
              label: Text('الشافعي'),
            ),
          ],
          selected: <AsrCalculation>{method},
          onSelectionChanged: (value) {
            widget.onData(value.first.name);
            setState(
              () {
                method = value.first;
              },
            );
          },
        )
      ],
    );
  }
}
