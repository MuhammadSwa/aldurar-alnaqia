import 'package:flutter/material.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/widgets/zikr_inline_text.dart';

/// One Arabic poetry bayt: [sadr] (first hemistich) and [ajz] (second).
///
/// Wide screens show both hemistichs side by side in classical two-column
/// form (sadr on the right, ajz on the left). Narrow screens stack them
/// (sadr right-aligned, ajz left-aligned) so long verses never squeeze.
class BaytWidget extends StatelessWidget {
  const BaytWidget({
    super.key,
    required this.sadr,
    required this.ajz,
    required this.fontSize,
  });

  final String sadr;
  final String ajz;

  /// Base font size from the page-level `fontSizeProvider` watch.
  final double fontSize;

  /// Width at and above which hemistichs sit side by side.
  static const double wideThreshold = 600;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= wideThreshold) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ZikrInlineText(
                      text: sadr,
                      fontSize: fontSize,
                      textAlign: TextAlign.right,),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: ZikrInlineText(
                      text: ajz, fontSize: fontSize, textAlign: TextAlign.left,),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ZikrInlineText(
                text: sadr, fontSize: fontSize, textAlign: TextAlign.right,),
            const SizedBox(height: 2),
            ZikrInlineText(
                text: ajz, fontSize: fontSize, textAlign: TextAlign.left,),
          ],
        );
      },
    );
  }
}
