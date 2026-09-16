import 'package:flutter/material.dart';

enum AsrCalculation { shafi, hanafi }

class AsrCalcSegmentedButton extends StatefulWidget {
  const AsrCalcSegmentedButton({super.key, required this.onData, this.initial});

  final void Function(String) onData;

  /// 'shafi' or 'hanafi' — pre-selects the saved value.
  final String? initial;

  @override
  State<AsrCalcSegmentedButton> createState() => _AsrCalculationWidget();
}

class _AsrCalculationWidget extends State<AsrCalcSegmentedButton> {
  late AsrCalculation method;

  @override
  void initState() {
    super.initState();
    method = widget.initial == 'hanafi'
        ? AsrCalculation.hanafi
        : AsrCalculation.shafi;
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'مذهب حساب وقت العصر',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
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
        ),
      ],
    );
  }
}
