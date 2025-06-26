import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:aldurar_alnaqia/audioPlayer/audioPlayer.dart'; // Has your audio Controller
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/widgets/stream_download_dialog.dart';

/// A versatile button that manages playing, streaming, and downloading audio.
///
/// It visually changes based on the audio file's state:
/// - Shows a progress indicator while downloading.
/// - Shows a filled "play" icon for downloaded files.
/// - Shows a standard "volume" icon for files that can be streamed or downloaded.
/// - Hides itself if the audio it represents is currently playing.
/// - Can optionally show a delete button for downloaded files.
class AudioActionButton extends StatelessWidget {
  const AudioActionButton({
    super.key,
    required this.id,
    required this.title,
    required this.url,
  });

  /// A unique identifier for the audio track (e.g., a narration ID).
  final String id;

  /// The title of the audio track, used for display and filenames.
  final String title;

  /// The URL to stream or download the audio from. Can be null.
  final String? url;

  @override
  Widget build(BuildContext context) {
    // It's generally better to 'put' controllers higher up in the widget tree
    // (e.g., in main.dart or a binding), but Get.put() here will work.
    final audioController = Get.put(Controller());
    final downloadController = Get.put(DownloaderController());

    // Check the file status when the widget is built to ensure the cache is up-to-date.
    downloadController.isFileDownloaded(id, DownloadType.narrations);

    return Obx(() {
      // --- Determine the current state ---
      final isPlayingThisTrack = audioController.currentMediaId.value == id;
      final isDownloading = downloadController.isDownloading(id);
      final isFileDownloaded = downloadController.fileStatusCache[id] ?? false;

      // 1. Hide button if the track is currently playing or has no URL.
      if (isPlayingThisTrack || url == null) {
        return const SizedBox.shrink();
      }

      // 2. Show progress indicator if the file is downloading.
      if (isDownloading) {
        return _buildDownloadingIndicator(downloadController);
      }

      // 3. Show play/delete buttons if the file is already downloaded.
      if (isFileDownloaded) {
        return _buildPlayLocalButton(context, audioController);
      }

      // 4. Default: Show button to trigger the stream/download dialog.
      return _buildStreamButton(context, audioController, downloadController);
    });
  }

  /// Builds the circular progress indicator shown during download.
  Widget _buildDownloadingIndicator(DownloaderController controller) {
    final progressNotifier = controller.downloadProgress[id];
    if (progressNotifier == null) return const SizedBox.shrink();

    return ValueListenableBuilder<double>(
      valueListenable: progressNotifier,
      builder: (context, progress, child) {
        return SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(value: progress, strokeWidth: 2.5),
              // Use a smaller, clickable icon to cancel
              InkWell(
                onTap: () => controller.cancelDownload(id),
                child: const Icon(Icons.close, size: 16),
                // tooltip: 'إلغاء التحميل',
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the button to play a file that exists locally.
  Widget _buildPlayLocalButton(BuildContext context, Controller controller) {
    return IconButton(
      // --- SUBTLE DIFFERENCE 1: A more distinct "Play" icon ---
      icon:
          const Icon(Icons.play_circle_filled),
      tooltip: 'تشغيل الصوت (محلي)',
      onPressed: () => controller.initPlayer(id, url!, title, true),
    );
  }

  /// Builds the default button to stream or download a file.
  Widget _buildStreamButton(
    BuildContext context,
    Controller audioController,
    DownloaderController downloadController,
  ) {
    return IconButton(
      // --- SUBTLE DIFFERENCE 2: The standard, less prominent icon ---
      icon: const Icon(Icons.volume_up),
      tooltip: 'استماع أو تحميل الصوت',
      onPressed: () => _showStreamDownloadDialog(
          context, audioController, downloadController),
    );
  }

  /// Builds the delete button for a downloaded file.
  Widget _buildDeleteButton(
      BuildContext context, DownloaderController controller) {
    return IconButton(
      onPressed: () => _showDeleteConfirmation(context, controller),
      icon: Icon(Icons.delete_outline, size: 22, color: Colors.grey.shade600),
      tooltip: 'حذف الملف المحمل',
    );
  }

  // --- Dialog Helper Methods ---

  void _showStreamDownloadDialog(
    BuildContext context,
    Controller audioController,
    DownloaderController downloadController,
  ) {
    final downloadItem = DownloadItem(
        id: id, title: title, url: url!, type: DownloadType.narrations);
    showDialog(
      context: context,
      builder: (dialogContext) => StreamOrDownloadDialog(
        item: downloadItem,
        onStream: () {
          Navigator.of(dialogContext).pop();
          audioController.initPlayer(id, url!, title, false);
        },
        onDownload: () {
          Navigator.of(dialogContext).pop();
          downloadController.startDownload(downloadItem);
        },
        onManageDownloads: () {
          Navigator.of(dialogContext).pop();
          context.push('/downloadManager/0');
        },
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, DownloaderController controller) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف ملف الصوت'),
        content: Text('هل أنت متأكد من حذف "$title"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              controller.deleteFile(id, DownloadType.narrations);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
