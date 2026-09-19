import 'package:material_ui/material_ui.dart';

/// Loading indicator for the book viewer: download progress when
/// [isDownloading] is true, generic "opening" text otherwise.
class BookLoadingView extends StatelessWidget {
  const BookLoadingView({
    super.key,
    required this.received,
    required this.total,
    required this.isDownloading,
  });

  final int received;
  final int? total;
  final bool isDownloading;

  @override
  Widget build(BuildContext context) {
    final downloadedMb = (received / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = total != null
        ? (total! / (1024 * 1024)).toStringAsFixed(1)
        : null;
    final progress =
        total != null && total! > 0 ? received / total! : null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: progress),
          const SizedBox(height: 16),
          Text(
            isDownloading
                ? (totalMb != null
                    ? '$downloadedMb / $totalMb م.ب'
                    : '$downloadedMb م.ب')
                : 'جاري فتح الكتاب...',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
