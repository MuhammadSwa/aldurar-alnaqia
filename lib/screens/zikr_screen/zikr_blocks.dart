/// Block model for zikr page content.
///
/// Raw [Zikr.content] strings use a tiny line-based format:
///
/// - blank line: block boundary (vertical spacing)
/// - `## ...`: section heading (e.g. `## الفصل الأول ...`)
/// - `<sadr> __ <ajz>`: one poetry bayt (two hemistichs)
/// - anything else: prose (consecutive lines form one paragraph)
///
/// [parseZikrBlocks] turns the raw string into blocks; widgets render each
/// block type. Inline styling (Quran, footnotes, quotes) stays inside the
/// text widgets and is unrelated to this structure.
sealed class ZikrBlock {
  const ZikrBlock();
}

/// Plain paragraph (one or more consecutive prose lines).
class ProseBlock extends ZikrBlock {
  final String text;
  const ProseBlock(this.text);
}

/// Section heading, stored without the leading `##`.
class HeadingBlock extends ZikrBlock {
  final String text;
  const HeadingBlock(this.text);
}

/// One Arabic poetry bayt: first hemistich ([sadr]) and second ([ajz]).
class BaytBlock extends ZikrBlock {
  final String sadr;
  final String ajz;
  const BaytBlock({required this.sadr, required this.ajz});
}

/// Separator between the two hemistichs of a bayt line.
const String baytSeparator = '__';

/// Splits raw zikr content into renderable blocks.
///
/// Forgiving by design: a line containing [baytSeparator] that does not
/// split into exactly two non-empty halves is kept as prose so no text is
/// ever dropped or mis-rendered.
List<ZikrBlock> parseZikrBlocks(String content) {
  final blocks = <ZikrBlock>[];
  final prose = <String>[];

  void flushProse() {
    if (prose.isEmpty) return;
    blocks.add(ProseBlock(prose.join('\n').trim()));
    prose.clear();
  }

  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flushProse();
      continue;
    }
    if (line.startsWith('##')) {
      flushProse();
      final heading = line.replaceFirst(RegExp(r'^#+\s*'), '').trim();
      if (heading.isNotEmpty) blocks.add(HeadingBlock(heading));
      continue;
    }
    if (line.contains(baytSeparator)) {
      final parts = line.split(baytSeparator);
      if (parts.length == 2) {
        final sadr = parts[0].trim();
        final ajz = parts[1].trim();
        if (sadr.isNotEmpty && ajz.isNotEmpty) {
          flushProse();
          blocks.add(BaytBlock(sadr: sadr, ajz: ajz));
          continue;
        }
      }
      // Malformed bayt line: fall through to prose.
    }
    prose.add(line);
  }
  flushProse();
  return blocks;
}
