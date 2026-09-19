import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/common/widgets/settings_card.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

/// Drawer font-size setting. Same [SettingsCard] row look as the
/// [SettingPopupTile] settings; the slider lives in a dialog.
///
/// Dragging previews live via [FontSizeNotifier.preview] (no disk write);
/// releasing persists once via [FontSizeNotifier.change].
class FontSizeSettingsWidget extends ConsumerWidget {
  const FontSizeSettingsWidget(
      {super.key, this.cardStyle = SettingsCardStyle.classic});

  final SettingsCardStyle cardStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = ref.watch(fontSizeProvider);
    return SettingsCard(
      style: cardStyle,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => const _FontSizeDialog(),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'حجم الخط',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Text(
                size.round().toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.format_size,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontSizeDialog extends ConsumerStatefulWidget {
  const _FontSizeDialog();

  @override
  ConsumerState<_FontSizeDialog> createState() => _FontSizeDialogState();
}

class _FontSizeDialogState extends ConsumerState<_FontSizeDialog> {
  late double _local;

  @override
  void initState() {
    super.initState();
    _local = ref.read(fontSizeProvider);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'حجم الخط',
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Slider(
            label: _local.round().toString(),
            divisions: 15,
            min: 16,
            max: 40,
            value: _local,
            onChanged: (v) {
              setState(() => _local = v);
              ref.read(fontSizeProvider.notifier).preview(v);
            },
            onChangeEnd: (v) {
              ref.read(fontSizeProvider.notifier).change(v);
            },
          ),
          Text('${_local.round()}'),
        ],
      ),
    );
  }
}
