import 'package:flutter/material.dart';

/// TEMPORARY lab: visual separator variations for the awrad/zikr tiles.
///
/// Same 4 sample rows in every section so the *separator* is what you
/// compare, not the content. Mock rows mirror [ZikrListViewTile]
/// (bold title, bookmark leading, chevron trailing) without navigation.
///
/// Delete after a choice is made, then apply the winner to
/// `ZikrListViewTile` / `AzkarListViewWidget`.
class TileSeparatorLabScreen extends StatelessWidget {
  const TileSeparatorLabScreen({super.key});

  static const _samples = <String>[
    'الحضرة الصديقية',
    'الصلوات اليسرية',
    'دلائل الخيرات',
    'أوراد ختام الصلاة',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فواصل البلاطات — مؤقت')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Section(
            number: '0',
            name: 'الحالي: بدون فاصل (أساس)',
            note: 'ListTile متتالية بلا أي فاصل — للمقارنة فقط.',
            child: _V0NoSeparator(samples: _samples),
          ),
          _Section(
            number: '1',
            name: 'فاصل Divider كامل',
            note: 'ListView.separated + Divider(height:1). أنظف وأرخص.',
            child: _V1FullDivider(samples: _samples),
          ),
          _Section(
            number: '2',
            name: 'فاصل مزاح (Inset)',
            note: 'Divider بمسافة من الطرفين — يخفف حدة الخط.',
            child: _V2InsetDivider(samples: _samples),
          ),
          _Section(
            number: '3',
            name: 'بطاقات منفصلة Cards',
            note: 'كل ذكر في Card مع فراغ 8 — فصل قوي وواضح.',
            child: _V3Cards(samples: _samples),
          ),
          _Section(
            number: '4',
            name: 'صفوف ملوّنة (Tonal)',
            note: 'خلفية surfaceContainerHigh مستديرة مع فراغ.',
            child: _V4Tonal(samples: _samples),
          ),
          _Section(
            number: '5',
            name: 'صفوف محددة (Outlined)',
            note: 'حد Outline رفيع + مستدير — فصل بدون ثقل اللون.',
            child: _V5Outlined(samples: _samples),
          ),
          _Section(
            number: '6',
            name: 'مجمّعة في حاوية واحدة',
            note: 'حاوية مستديرة واحدة وفواصل داخلية — نمط iOS.',
            child: _V6Grouped(samples: _samples),
          ),
          _Section(
            number: '7',
            name: 'شريط تمييز جانبي',
            note: 'شريط primary رفيع على الطرف + فراغ — فصل مع هوية.',
            child: _V7AccentBar(samples: _samples),
          ),
          _Section(
            number: '8',
            name: 'تظليل متبادل (Zebra)',
            note: 'صف ملوّن وصف شفاف بالتناوب — بدون خطوط.',
            child: _V8Zebra(samples: _samples),
          ),
        ],
      ),
    );
  }
}

// -- Section shell --------------------------------------------------------

class _Section extends StatelessWidget {
  final String number;
  final String name;
  final String note;
  final Widget child;

  const _Section({
    required this.number,
    required this.name,
    required this.note,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: scheme.primary,
                child: Text(
                  number,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(note, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Mock of ZikrListViewTile visuals (no navigation/bookmark state).
Widget _mockTile(String title) {
  return ListTile(
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    trailing: const Icon(Icons.chevron_right),
    leading: const Icon(Icons.bookmark_outline_rounded),
    onTap: () {},
  );
}

// -- 0: baseline ------------------------------------------------------------

class _V0NoSeparator extends StatelessWidget {
  final List<String> samples;
  const _V0NoSeparator({required this.samples});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final s in samples) _mockTile(s)],
    );
  }
}

// -- 1: full divider --------------------------------------------------------

class _V1FullDivider extends StatelessWidget {
  final List<String> samples;
  const _V1FullDivider({required this.samples});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < samples.length; i++) ...[
          _mockTile(samples[i]),
          if (i != samples.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

// -- 2: inset divider --------------------------------------------------------

class _V2InsetDivider extends StatelessWidget {
  final List<String> samples;
  const _V2InsetDivider({required this.samples});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < samples.length; i++) ...[
          _mockTile(samples[i]),
          if (i != samples.length - 1)
            const Divider(height: 1, indent: 56, endIndent: 16),
        ],
      ],
    );
  }
}

// -- 3: separate cards -------------------------------------------------------

class _V3Cards extends StatelessWidget {
  final List<String> samples;
  const _V3Cards({required this.samples});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < samples.length; i++) ...[
            Card(
              margin: EdgeInsets.zero,
              child: _mockTile(samples[i]),
            ),
            if (i != samples.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// -- 4: tonal rows -----------------------------------------------------------

class _V4Tonal extends StatelessWidget {
  final List<String> samples;
  const _V4Tonal({required this.samples});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < samples.length; i++) ...[
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _mockTile(samples[i]),
            ),
            if (i != samples.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// -- 5: outlined rows --------------------------------------------------------

class _V5Outlined extends StatelessWidget {
  final List<String> samples;
  const _V5Outlined({required this.samples});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < samples.length; i++) ...[
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _mockTile(samples[i]),
            ),
            if (i != samples.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// -- 6: grouped container ----------------------------------------------------

class _V6Grouped extends StatelessWidget {
  final List<String> samples;
  const _V6Grouped({required this.samples});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < samples.length; i++) ...[
            _mockTile(samples[i]),
            if (i != samples.length - 1)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: scheme.outline.withValues(alpha: 0.4),
              ),
          ],
        ],
      ),
    );
  }
}

// -- 7: accent bar -----------------------------------------------------------

class _V7AccentBar extends StatelessWidget {
  final List<String> samples;
  const _V7AccentBar({required this.samples});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < samples.length; i++) ...[
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  right: BorderSide(color: scheme.primary, width: 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: _mockTile(samples[i]),
            ),
            if (i != samples.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// -- 8: zebra ----------------------------------------------------------------

class _V8Zebra extends StatelessWidget {
  final List<String> samples;
  const _V8Zebra({required this.samples});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < samples.length; i++)
          Container(
            color: i.isEven
                ? scheme.secondaryContainer.withValues(alpha: 0.45)
                : Colors.transparent,
            child: _mockTile(samples[i]),
          ),
      ],
    );
  }
}
