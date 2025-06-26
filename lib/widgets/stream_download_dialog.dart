// This dialog is specific to this screen, so it's fine to keep it here.
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:flutter/material.dart';

class StreamOrDownloadDialog extends StatelessWidget {
  const StreamOrDownloadDialog({
    super.key,
    required this.item,
    required this.onStream,
    required this.onDownload,
    required this.onManageDownloads,
  });

  final DownloadItem item;
  final VoidCallback onStream;
  final VoidCallback onDownload;
  final VoidCallback onManageDownloads;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(item.title,
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
            onPressed: onStream,
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildOptionButton(
            context,
            icon: Icons.download_for_offline_outlined,
            label: 'تحميل',
            subtitle: 'سيكون متاحًا بدون إنترنت',
            onPressed: onDownload,
            color: Colors.green,
          ),
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
            backgroundColor: color.withOpacity(0.1),
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
                            fontSize: 12, color: color.withOpacity(0.9))),
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
