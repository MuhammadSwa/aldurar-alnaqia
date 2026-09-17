import 'package:aldurar_alnaqia/common/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TEMPORARY theme playground: a mock of the app whose colors the user can
/// tweak. Preview-only — nothing here touches the real app theme.
class ThemePreviewScreen extends StatefulWidget {
  const ThemePreviewScreen({super.key});

  @override
  State<ThemePreviewScreen> createState() => _ThemePreviewScreenState();
}

class _ThemePreviewScreenState extends State<ThemePreviewScreen> {
  static const _seeds = <(String, Color)>[
    ('زمردي (الحالي للفاتح)', Color(0xFF0B6B4F)),
    ('تركوازي (الحالي للداكن)', Color(0xFF4DD0C4)),
  ];

  int _seedIndex = 0;
  Color? _customSeed;
  final _overrides = <String, Color>{};
  final _customSeedController = TextEditingController();
  bool _dark = false;
  double _primaryShift = 0; // -0.2 .. +0.2 lightness delta on primary.

  @override
  void dispose() {
    _customSeedController.dispose();
    super.dispose();
  }

  Color get _seed => _customSeed ?? _seeds[_seedIndex].$2;

  ColorScheme _scheme() {
    final brightness = _dark ? Brightness.dark : Brightness.light;
    final base = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final shiftedPrimary = _primaryShift == 0
        ? base.primary
        : HSLColor.fromColor(base.primary)
            .withLightness((HSLColor.fromColor(base.primary).lightness +
                    _primaryShift)
                .clamp(0.0, 1.0),)
            .toColor();
    return base.copyWith(
      primary: _overrides['primary'] ?? shiftedPrimary,
      secondaryContainer:
          _overrides['secondaryContainer'] ?? base.secondaryContainer,
      surface: _overrides['surface'] ?? base.surface,
      onSurface: _overrides['onSurface'] ?? base.onSurface,
    );
  }

  void _useSeed(int i) => setState(() {
        _seedIndex = i;
        _customSeed = null;
        _customSeedController.clear();
        _overrides.clear();
        _primaryShift = 0;
      });

  Future<void> _applyCustomSeed() async {
    final c = _parseHex(_customSeedController.text);
    if (c == null) return;
    setState(() {
      _customSeed = c;
      _overrides.clear();
      _primaryShift = 0;
    });
  }

  Future<void> _editRole(String role, Color current) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => _HexEditDialog(initial: current, title: role),
    );
    if (picked != null) setState(() => _overrides[role] = picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _scheme();
    final theme = AppTheme.fromScheme(scheme).copyWith(
      // Match the app's current primary-tone overrides when the
      // corresponding seeds are picked unshifted? No — preview is raw.
    );
    return Scaffold(
      appBar: AppBar(title: const Text('تجربة الألوان — مؤقت')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MockApp(theme: theme, dark: _dark),
            const SizedBox(height: 16),
            _section(context, 'البذرة (تغييرها يصفّر التعديلات)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _seeds.length; i++)
                  ChoiceChip(
                    label: Text(_seeds[i].$1),
                    selected:
                        _customSeed == null && _seedIndex == i,
                    avatar: CircleAvatar(
                      backgroundColor: _seeds[i].$2,
                      radius: 8,
                    ),
                    onSelected: (_) => _useSeed(i),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customSeedController,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'بذرة مخصصة (hex)',
                      hintText: '#0B6B4F',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _applyCustomSeed(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _applyCustomSeed,
                  child: const Text('تطبيق'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section(context, 'إضاءة الأساسي (primary)'),
            Row(
              children: [
                IconButton(
                  tooltip: 'أغمق',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(() => _primaryShift =
                      (_primaryShift - 0.05).clamp(-0.2, 0.2),),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_primaryShift + 0.2) / 0.4,
                  ),
                ),
                IconButton(
                  tooltip: 'أفتح',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _primaryShift =
                      (_primaryShift + 0.05).clamp(-0.2, 0.2),),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section(context, 'السطوع'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('فاتح')),
                ButtonSegment(value: true, label: Text('داكن')),
              ],
              selected: {_dark},
              onSelectionChanged: (s) =>
                  setState(() => _dark = s.first),
            ),
            const SizedBox(height: 12),
            _section(context, 'الألوان الحالية (اضغط للتعديل)'),
            _hexRow('primary', scheme.primary),
            _hexRow('secondaryContainer', scheme.secondaryContainer),
            _hexRow('surface', scheme.surface),
            _hexRow('onSurface', scheme.onSurface),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() {
                _seedIndex = 0;
                _customSeed = null;
                _customSeedController.clear();
                _overrides.clear();
                _dark = false;
                _primaryShift = 0;
              }),
              child: const Text('إعادة ضبط'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        textAlign: TextAlign.right,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _hexRow(String name, Color color) {
    final hex =
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
    final overridden = _overrides.containsKey(name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _editRole(name, color),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name, textDirection: TextDirection.ltr),
              ),
              if (overridden)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.edit, size: 14),
                ),
              Text(
                hex,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontWeight:
                      overridden ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Parses #RRGGBB or #AARRGGBB (with or without #). Null when invalid.
Color? _parseHex(String s) {
  var h = s.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

/// Small editor: preset swatches + hex field. Returns the picked color.
class _HexEditDialog extends StatefulWidget {
  final Color initial;
  final String title;
  const _HexEditDialog({required this.initial, required this.title});

  @override
  State<_HexEditDialog> createState() => _HexEditDialogState();
}

class _HexEditDialogState extends State<_HexEditDialog> {
  static const _presets = [
    Colors.green,
    Color(0xFF0B6B4F),
    Color(0xFF4DD0C4),
    Color(0xFF1E4FA3),
    Color(0xFF8A6A0E),
    Color(0xFF7C2D3E),
    Colors.black,
    Colors.white,
    Colors.grey,
    Colors.red,
    Colors.orange,
    Colors.blue,
  ];

  late Color _current;
  late TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
    _controller = TextEditingController(
      text:
          '#${widget.initial.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fromHex() {
    final c = _parseHex(_controller.text);
    setState(() {
      if (c == null) {
        _error = 'صيغة غير صالحة (مثال: #0B6B4F)';
      } else {
        _error = null;
        _current = c;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, textAlign: TextAlign.right),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _current,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final c in _presets)
                  InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () => setState(() {
                      _current = c;
                      _error = null;
                      _controller.text =
                          '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}';
                    }),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c == _current
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade400,
                          width: c == _current ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'hex',
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: _error,
              ),
              onSubmitted: (_) => _fromHex(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _fromHex,
          child: const Text('من الـ hex'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_current),
          child: const Text('تم'),
        ),
      ],
    );
  }
}

/// Static mock of the app's look: app bar + today section + tiles + nav bar.
class _MockApp extends StatelessWidget {
  final ThemeData theme;
  final bool dark;
  const _MockApp({required this.theme, required this.dark});

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => DefaultTextStyle(
          // No Scaffold inside the mock, so uncolored texts would inherit
          // the ambient style (e.g. light text in dark mode) instead of
          // the preview theme's body color.
          style: Theme.of(context).textTheme.bodyMedium!,
          child: Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: scheme.outline.withValues(alpha: 0.4),),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: scheme.secondaryContainer,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10,),
                  child: Row(
                    children: [
                      Icon(Icons.menu,
                          size: 20,
                          color: scheme.onSecondaryContainer,),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الدرر النقية',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 18,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      Icon(Icons.search,
                          size: 20,
                          color: scheme.onSecondaryContainer,),
                    ],
                  ),
                ),
                Container(
                  color: scheme.surface,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.today_rounded,
                              size: 20, color: scheme.primary,),
                          const SizedBox(width: 8),
                          const Text(
                            'أوراد اليوم',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _tile(context, 'ورد يوم الخميس',
                          Icons.chevron_right, Icons.bookmark,),
                      _tile(context, 'أوراد ختام الصلاة',
                          Icons.chevron_right, Icons.bookmark_outline_rounded,),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10,),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC14A3A)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(LucideIcons.sunset,
                                  size: 18,
                                  color: Color(0xFFC14A3A),),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('المغرب')),
                            const Text('06:12 م'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: scheme.secondaryContainer,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8,),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navItem(context, Icons.home, 'الرئيسية', true),
                      _navItem(context, Icons.timer_outlined,
                          'مواقيت الصلاة', false,),
                      _navItem(
                          context, Icons.list, 'الأوراد', false,),
                      _navItem(context, Icons.book_outlined,
                          'المكتبة', false,),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _tile(
      BuildContext context, String title, IconData trail, IconData lead,) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(lead, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
          Icon(trail, size: 20, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _navItem(
      BuildContext context, IconData icon, String label, bool selected,) {
    final scheme = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: selected ? scheme.onPrimary : scheme.onSecondaryContainer,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ],
    );
    if (!selected) return content;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(99),
      ),
      child: content,
    );
  }
}
