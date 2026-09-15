import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

/// Inline-styled text for zikr content.
///
/// Handles inline spans only: footnote refs (`[^1]`), Quran (`﴿﴾`),
/// hadith quotes (`«»`), bracket references and numbering.
/// Block structure (headings, poetry bayts) is handled upstream by
/// [parseZikrBlocks] and never reaches a regex here.
///
/// Previously built on `easy_rich_text`; now a small local
/// regex-to-[TextSpan] parser with the same match precedence
/// (earliest match wins, overlaps dropped).
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
    const fontFamily = 'AmiriQuran';
    final base = Theme.of(context).textTheme.bodyMedium!;

    final defaultStyle = base.copyWith(
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : null,
    );

    return Text.rich(
      TextSpan(
        style: defaultStyle,
        children: _buildSpans(context, fontSize, base, fontFamily),
      ),
      textAlign: textAlign,
    );
  }

  List<InlineSpan> _buildSpans(
    BuildContext context,
    double fontSize,
    TextStyle base,
    String fontFamily,
  ) {
    // Order defines precedence only for matches starting at the same
    // offset; otherwise the earliest match in the text wins.
    final styles = <TextStyle?>[
      // 0. Footnote refs — handled by _footnoteSpan, style unused.
      null,
      // 1. Hadith and quoted text.
      TextStyle(fontWeight: FontWeight.w900, color: base.color),
      // 2. Quranic verses and the basmala.
      TextStyle(fontFamily: fontFamily, color: base.color),
      // 3. Sources and reader hints.
      base.copyWith(fontSize: fontSize * .7),
      // 4. Line numbering at line starts.
      base.copyWith(fontSize: fontSize * .7),
    ];
    final patterns = <RegExp>[
      // Footnote refs stored as [^1] in data, shown superscript as [1].
      RegExp(r'\[\^[0-9]+\]', multiLine: true),
      // Hadith and quoted text.
      RegExp('«[^»]+»', multiLine: true),
      // Quranic verses and the basmala.
      RegExp(
        '﴿[^﴾]+﴾|بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        multiLine: true,
      ),
      // Sources like [البقرة: 255] / [البقرة: ٢٥٥] and reader hints.
      // Accepts ASCII, Arabic-Indic (٠-٩) and Eastern (۰-۹) digits.
      RegExp(
        r'\[[\u0600-\u06FF\s]+:[^\]]+[0-9\u0660-\u0669\u06F0-\u06F9]\]|\[تقرأ مرة واحدة للمتعجل\]',
        multiLine: true,
      ),
      // Line numbering like "1." or "2/3." at line starts,
      // styled like footer text (same color, smaller).
      // Needed so `^` matches each line start, not just the
      // start of the whole text (e.g. numbered lines like "1." / "2/3.").
      RegExp(r'^[0-9/]+\.', multiLine: true),
    ];

    final matches = <_Match>[];
    for (var i = 0; i < patterns.length; i++) {
      for (final m in patterns[i].allMatches(text)) {
        matches.add(_Match(m.start, m.end, i));
      }
    }
    // Earliest start wins; longer match, then lower rule index,
    // wins ties at the same offset.
    matches.sort((a, b) {
      if (a.start != b.start) return a.start.compareTo(b.start);
      final len = (b.end - b.start).compareTo(a.end - a.start);
      if (len != 0) return len;
      return a.rule.compareTo(b.rule);
    });

    final spans = <InlineSpan>[];
    var pos = 0;
    for (final m in matches) {
      if (m.start < pos) continue; // overlapped by an earlier match
      if (m.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, m.start)));
      }
      if (m.rule == 0) {
        spans.add(_footnoteSpan(context, fontSize, m));
      } else {
        spans.add(
          TextSpan(
            text: text.substring(m.start, m.end),
            style: styles[m.rule],
          ),
        );
      }
      pos = m.end;
    }
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos)));
    }
    return spans;
  }

  WidgetSpan _footnoteSpan(BuildContext context, double fontSize, _Match m) {
    final label = text.substring(m.start, m.end).replaceAll('^', '');
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
  }
}

class _Match {
  const _Match(this.start, this.end, this.rule);

  final int start;
  final int end;
  final int rule;
}
