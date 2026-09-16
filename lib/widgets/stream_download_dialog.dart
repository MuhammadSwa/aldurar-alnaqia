// This dialog is specific to this screen, so it's fine to keep it here.
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StreamOrDownloadDialog extends StatefulWidget {
  const StreamOrDownloadDialog({
    super.key,
    required this.item,
    required this.onStream,
    required this.onDownload,
    this.showRememberOption = false,
    this.onRemember,
  });

  final DownloadItem item;
  final VoidCallback onStream;
  final VoidCallback onDownload;

  /// When true, shows a "تذكر الاختيار" checkbox. If the user checks it,
  /// [onRemember] is called with `true` for direct open/stream and `false`
  /// for download, so the caller can persist the choice via
  /// `fileOpenActionProvider` and skip the dialog next time.
  final bool showRememberOption;

  /// Called only when [showRememberOption] is true and the checkbox is
  /// checked. [stream] is true for the direct-open action, false for download.
  final ValueChanged<bool>? onRemember;

  @override
  State<StreamOrDownloadDialog> createState() => _StreamOrDownloadDialogState();
}

class _StreamOrDownloadDialogState extends State<StreamOrDownloadDialog> {
  bool _rememberChoice = false;

  void _handleStream() {
    if (widget.showRememberOption && _rememberChoice) {
      widget.onRemember?.call(true);
    }
    widget.onStream();
  }

  void _handleDownload() {
    if (widget.showRememberOption && _rememberChoice) {
      widget.onRemember?.call(false);
    }
    widget.onDownload();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.item.title,
          style: const TextStyle(fontSize: 18), textAlign: TextAlign.center,),
      contentPadding: const EdgeInsets.all(16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('الملف غير مُحمل. الرجاء اختيار أحد الخيارات:',
              textAlign: TextAlign.center,),
          const SizedBox(height: 20),
          _buildOptionButton(
            context,
            icon: Icons.cloud_outlined,
            label: 'فتح مباشر',
            subtitle: 'يتطلب اتصالاً بالإنترنت',
            onPressed: _handleStream,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _buildOptionButton(
            context,
            icon: Icons.download_for_offline_outlined,
            label: 'تحميل',
            subtitle: 'سيكون متاحًا بدون إنترنت',
            onPressed: _handleDownload,
            color: colorScheme.secondary,
          ),
          if (widget.showRememberOption) ...[
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.rtl,
              child: CheckboxListTile(
                value: _rememberChoice,
                onChanged: (value) {
                  setState(() {
                    _rememberChoice = value ?? false;
                  });
                },
                title: const Text('تذكر الاختيار',
                    style: TextStyle(fontSize: 14),),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        width: double.infinity,
        // Use the default ElevatedButton constructor, not .icon
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.1),
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            // We are building our own Row, so we don't need alignment here
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          // Build the child manually using a Row
          child: Row(
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14,),),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: color.withValues(alpha: 0.9),),),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared `showDialog` wiring for files that are not downloaded yet.
///
/// Handles the "تذكر الاختيار" persistence + popping + dispatching to
/// [onOpen]/download, replacing the duplicated blocks in `LibraryScreen`
/// and `PlayAudioBtnZikrPage`.
Future<void> showStreamOrDownloadDialog({
  required BuildContext context,
  required WidgetRef ref,
  required DownloadItem item,
  required VoidCallback onOpen,
  VoidCallback? onDownload,
}) {
  return showDialog(
    context: context,
    builder: (dialogContext) => StreamOrDownloadDialog(
      item: item,
      showRememberOption: true,
      onRemember: (stream) {
        ref.read(fileOpenActionProvider.notifier).set(
            stream ? FileOpenAction.open : FileOpenAction.download,);
      },
      onStream: () {
        Navigator.of(dialogContext).pop();
        onOpen();
      },
      onDownload: () {
        Navigator.of(dialogContext).pop();
        if (onDownload != null) {
          onDownload();
        } else {
          ref.read(downloaderProvider).startDownload(item);
        }
      },
    ),
  );
}
