import 'package:material_ui/material_ui.dart';

/// Inline-styled text for zikr content.
///
/// Handles inline spans only: footnote refs (`[^1]`), Quran (`﴿﴾`),
/// hadith quotes (`«»`), bracket references and numbering.
/// Block structure (headings, poetry bayts) is handled upstream by
/// `parseZikrBlocks` and never reaches a regex here.
///
/// Performance notes:
/// - [fontSize] is passed down from the page (which watches
///   `fontSizeProvider` once) so one text block does not subscribe per
///   paragraph.
/// - Regexes are `static final` (compiled once). Previously 5 regexes were
///   recompiled per block per build.
/// - Footnotes render as superscript [WidgetSpan]
class ZikrInlineText extends StatelessWidget {
  const ZikrInlineText({
    required this.text,
    required this.fontSize,
    super.key,
    this.textAlign = TextAlign.justify,
    this.sizeFactor = 1.0,
    this.bold = false,
  });

  final String text;

  /// Base font size from the page-level `fontSizeProvider` watch.
  final double fontSize;
  final TextAlign textAlign;
  final double sizeFactor;
  final bool bold;

  static final RegExp _footnotePattern = RegExp(r'\[\^[0-9]+\]');
  static final RegExp _hadithPattern = RegExp('«[^»]+»');
  static final RegExp _quranPattern = RegExp(
    '﴿[^﴾]+﴾|بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
  );
  static final RegExp _sourcePattern = RegExp(
    r'\[[\u0600-\u06FF\s]+:[^\]]+[0-9\u0660-\u0669\u06F0-\u06F9]\]|\[تقرأ مرة واحدة للمتعجل\]',
  );
  static final RegExp _numberingPattern =
      RegExp(r'^[0-9/]+\.', multiLine: true);

  @override
  Widget build(BuildContext context) {
    final effectiveSize = fontSize * sizeFactor;
    const fontFamily = 'AmiriQuran';
    final base = Theme.of(context).textTheme.bodyMedium!;

    final defaultStyle = base.copyWith(
      fontSize: effectiveSize,
      fontWeight: bold ? FontWeight.bold : null,
    );

    return Text.rich(
      TextSpan(
        style: defaultStyle,
        children: _buildSpans(effectiveSize, base, fontFamily),
      ),
      textAlign: textAlign,
    );
  }

  List<InlineSpan> _buildSpans(
    double effectiveSize,
    TextStyle base,
    String fontFamily,
  ) {
    // Order defines precedence only for matches starting at the same
    // offset; otherwise the earliest match in the text wins.
    final styles = <TextStyle?>[
      // 0. Footnote refs — plain small span, style unused (see below).
      null,
      // 1. Hadith and quoted text.
      TextStyle(fontWeight: FontWeight.w900, color: base.color),
      // 2. Quranic verses and the basmala.
      TextStyle(fontFamily: fontFamily, color: base.color),
      // 3. Sources and reader hints.
      base.copyWith(fontSize: effectiveSize * .7),
      // 4. Line numbering at line starts.
      base.copyWith(fontSize: effectiveSize * .7),
    ];
    final patterns = <RegExp>[
      _footnotePattern,
      _hadithPattern,
      _quranPattern,
      _sourcePattern,
      _numberingPattern,
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

    final footnoteStyle = base.copyWith(fontSize: effectiveSize * .5);

    final spans = <InlineSpan>[];
    var pos = 0;
    for (final m in matches) {
      if (m.start < pos) continue; // overlapped by an earlier match
      if (m.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, m.start)));
      }
      if (m.rule == 0) {
        // Strip the caret: [^12] -> [12]. Superscript via WidgetSpan + Transform:
        // the translate only affects paint offset, so line height stays stable.
        final label = text.substring(m.start, m.end).replaceAll('^', '');
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Transform.translate(
              offset: Offset(0, -effectiveSize * 0.35),
              child: Text(label, style: footnoteStyle),
            ),
          ),
        );
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
}

class _Match {
  const _Match(this.start, this.end, this.rule);

  final int start;
  final int end;
  final int rule;
}
