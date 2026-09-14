import 'package:easy_rich_text/easy_rich_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

/// Inline-styled text for zikr content.
///
/// Handles inline spans only: footnote refs (`[^1]`), Quran (`﴿﴾`),
/// hadith quotes (`«»`), bracket references and numbering.
/// Block structure (headings, poetry bayts) is handled upstream by
/// [parseZikrBlocks] and never reaches a regex here.
class ZikrInlineText extends ConsumerWidget {
  const ZikrInlineText({
    super.key,
    required this.text,
    this.textAlign = TextAlign.justify,
    this.sizeFactor = 1.0,
    this.bold = false,
  });

  final String text;
  final TextAlign textAlign;
  final double sizeFactor;
  final bool bold;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(fontSizeProvider) * sizeFactor;
    final fontFamily = ref.watch(fontFamilyProvider);
    final base = Theme.of(context).textTheme.bodyMedium!;

    return EasyRichText(
      text,
      textAlign: textAlign,
      // Needed so `^` in patterns matches each line start, not just the
      // start of the whole text (e.g. numbered lines like "1." / "2/3.").
      multiLine: true,
      defaultStyle: base.copyWith(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : null,
      ),
      patternList: [
        // Footnote refs stored as [^1] in data, shown superscript as [1].
        EasyRichTextPattern(
          targetString: r'\[\^[0-9]+\]',
          matchBuilder: (context, match) {
            final label = match?[0]?.replaceAll('^', '') ?? '';
            return WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Transform.translate(
                offset: Offset(0, -fontSize * 0.35),
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(fontSize: fontSize * .6),
                ),
              ),
            );
          },
        ),
        // Hadith and quoted text.
        EasyRichTextPattern(
          targetString: const ['«[^»]+»'],
          style: TextStyle(fontWeight: FontWeight.w900, color: base.color),
        ),
        // Quranic verses and the basmala.
        EasyRichTextPattern(
          targetString: const [
            r'﴿[^﴾]+﴾',
            'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
          ],
          style: TextStyle(fontFamily: fontFamily, color: base.color),
        ),
        // Sources like [البقرة: 255] / [البقرة: ٢٥٥] and reader hints.
        // Accepts ASCII, Arabic-Indic (٠-٩) and Eastern (۰-۹) digits.
        EasyRichTextPattern(
          targetString: const [
            r'\[[\u0600-\u06FF\s]+:[^\]]+[0-9\u0660-\u0669\u06F0-\u06F9]\]',
            r'\[تقرأ مرة واحدة للمتعجل\]',
          ],
          style: base.copyWith(fontSize: fontSize * .7),
        ),
        // Line numbering like "1." or "2/3." at line starts,
        // styled like footer text (same color, smaller).
        EasyRichTextPattern(
          targetString: r'^[0-9/]+\.',
          style: base.copyWith(fontSize: fontSize * .7),
        ),
      ],
    );
  }
}
