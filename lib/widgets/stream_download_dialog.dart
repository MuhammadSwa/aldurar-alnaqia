// This dialog is specific to this screen, so it's fine to keep it here.
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:flutter/material.dart';

class StreamOrDownloadDialog extends StatefulWidget {
  const StreamOrDownloadDialog({
    super.key,
    required this.item,
    required this.onStream,
    required this.onDownload,
    required this.onManageDownloads,
    this.showRememberOption = false,
    this.onRemember,
  });

  final DownloadItem item;
  final VoidCallback onStream;
  final VoidCallback onDownload;
  final VoidCallback onManageDownloads;

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
    return AlertDialog(
      title: Text(widget.item.title,
          style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
      contentPadding: const EdgeInsets.all(16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('الملف غير مُحمل. الرجاء اختيار أحد الخيارات:',
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          _buildOptionButton(
            context,
            icon: Icons.cloud_outlined,
            label: 'فتح مباشر',
            subtitle: 'يتطلب اتصالاً بالإنترنت',
            onPressed: _handleStream,
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildOptionButton(
            context,
            icon: Icons.download_for_offline_outlined,
            label: 'تحميل',
            subtitle: 'سيكون متاحًا بدون إنترنت',
            onPressed: _handleDownload,
            color: Colors.green,
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
                    style: TextStyle(fontSize: 14)),
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
              // Your Icon
              Icon(icon, size: 24),
              const SizedBox(width: 16), // Add space between icon and text

              // Use Expanded HERE inside your own Row
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: color.withValues(alpha: 0.9))),
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
