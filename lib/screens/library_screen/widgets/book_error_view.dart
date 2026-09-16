import 'package:flutter/material.dart';

/// Error state for the book viewer with retry / offline / browser actions.
class BookErrorView extends StatelessWidget {
  const BookErrorView({
    super.key,
    required this.onRetry,
    required this.onDownloadOffline,
    required this.onOpenBrowser,
  });

  final VoidCallback onRetry;
  final VoidCallback onDownloadOffline;
  final VoidCallback onOpenBrowser;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 64, color: colorScheme.onSurfaceVariant,),
            const SizedBox(height: 16),
            const Text(
              'تعذّر فتح الكتاب',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'تحقق من الاتصال بالإنترنت وحاول مجددًا، أو حمّل الكتاب للقراءة دون إنترنت.',
              style:
                  TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
                OutlinedButton.icon(
                  onPressed: onDownloadOffline,
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: const Text('تحميل للقراءة دون إنترنت'),
                ),
                TextButton.icon(
                  onPressed: onOpenBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('فتح في المتصفح'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
