import 'package:aldurar_alnaqia/screens/library_screen/library_screen.dart';
import 'package:aldurar_alnaqia/widgets/stream_download_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:aldurar_alnaqia/audioPlayer/audioPlayer.dart'; // Assuming this has 'Controller'
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';

class PlayAudioBtnZikrPage extends StatelessWidget {
  const PlayAudioBtnZikrPage({
    super.key,
    required this.title,
    required this.url,
    required this.id,
  });

  final String title;
  final String? url;
  final String id;

  @override
  Widget build(BuildContext context) {
    // Using Get.find is fine if you are SURE the controller is already 'put' by a parent.
    // Get.put() is safer as it will find it or create it.
    final audioController = Get.put(Controller());
    final downloadController = Get.put(DownloaderController());

    downloadController.isFileDownloaded(id, DownloadType.narrations);

    return Obx(() {
      final isPlayingThisUrl = audioController.url.value == url;
      final isFileDownloaded = downloadController.fileStatusCache[id] ?? false;
      final isDownloading = downloadController.isDownloading(id);

      if (url == null || isPlayingThisUrl) {
        return Container();
      }

      if (isDownloading) {
        final progressNotifier = downloadController.downloadProgress[id];
        return progressNotifier != null
            ? _buildProgressIndicator(
                progressNotifier, () => downloadController.cancelDownload(id))
            : const SizedBox.shrink();
      }

      if (isFileDownloaded) {
        return IconButton(
          onPressed: () => audioController.initPlayer(url!, title, true),
          icon: const Icon(Icons.volume_up),
          tooltip: 'تشغيل الصوت (محلي)',
        );
      }

      return IconButton(
        onPressed: () => _showStreamDownloadDialog(
            context, audioController, downloadController),
        icon: const Icon(Icons.volume_up),
        tooltip: 'استماع أو تحميل الصوت',
      );
    });
  }

  void _showStreamDownloadDialog(
    BuildContext context,
    Controller audioController,
    DownloaderController downloadController,
  ) {
    final downloadItem = DownloadItem(
      id: id,
      title: title,
      url: url!,
      type: DownloadType.narrations,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StreamOrDownloadDialog(
          item: downloadItem,
          onStream: () {
            Navigator.of(dialogContext).pop();
            audioController.initPlayer(url!, title, false);
          },
          onDownload: () {
            Navigator.of(dialogContext).pop();
            downloadController.startDownload(downloadItem);
          },
          onManageDownloads: () {
            Navigator.of(dialogContext).pop();
            context.push('/downloadManager/0');
          },
        );
      },
    );
  }

  Widget _buildProgressIndicator(
      ValueNotifier<double> progressNotifier, VoidCallback onCancel) {
    return ValueListenableBuilder<double>(
      valueListenable: progressNotifier,
      builder: (context, progress, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(value: progress, strokeWidth: 2),
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'إلغاء التحميل',
            ),
          ],
        );
      },
    );
  }
}

// --- FIXED ENHANCED WIDGET ---

class PlayAudioBtnZikrPageEnhanced extends StatelessWidget {
  const PlayAudioBtnZikrPageEnhanced({
    super.key,
    required this.title,
    required this.url,
    required this.id,
    this.allowDelete = true,
  });

  final String title;
  final String? url;
  final String id;
  final bool allowDelete;

  @override
  Widget build(BuildContext context) {
    final audioController = Get.put(Controller());
    final downloadController = Get.put(DownloaderController());

    downloadController.isFileDownloaded(id, DownloadType.narrations);

    return Obx(() {
      if (url == null || audioController.url.value == url) {
        return Container();
      }

      final isDownloading = downloadController.isDownloading(id);
      final isFileDownloaded = downloadController.fileStatusCache[id] ?? false;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPlayButton(
            context,
            audioController,
            downloadController,
            isDownloading,
            isFileDownloaded,
          ),
          if (isFileDownloaded && allowDelete) ...[
            const SizedBox(width: 4),
            _buildDeleteButton(context, downloadController),
          ],
        ],
      );
    });
  }

  Widget _buildPlayButton(
    BuildContext context,
    Controller audioController,
    DownloaderController downloadController,
    bool isDownloading,
    bool isFileDownloaded,
  ) {
    if (isDownloading) {
      final progressNotifier = downloadController.downloadProgress[id];
      return progressNotifier != null
          ? SizedBox(
              width: 24,
              height: 24,
              child: _buildProgressIndicator(progressNotifier,
                  () => downloadController.cancelDownload(id)),
            )
          : const SizedBox.shrink();
    }

    if (isFileDownloaded) {
      return IconButton(
        onPressed: () => audioController.initPlayer(url!, title, true),
        icon: Icon(Icons.volume_up, color: Theme.of(context).primaryColor),
        tooltip: 'تشغيل الصوت (محلي)',
      );
    }

    return IconButton(
      onPressed: () => _showStreamDownloadDialog(
          context, audioController, downloadController),
      icon: const Icon(Icons.volume_up),
      tooltip: 'استماع أو تحميل الصوت',
    );
  }

  Widget _buildProgressIndicator(
      ValueNotifier<double> progressNotifier, VoidCallback onCancel) {
    return ValueListenableBuilder<double>(
      valueListenable: progressNotifier,
      builder: (context, progress, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(value: progress, strokeWidth: 2),
            InkWell(
              onTap: onCancel,
              child: const Icon(Icons.close, size: 16),
            ),
          ],
        );
      },
    );
  }

  void _showStreamDownloadDialog(
    BuildContext context,
    Controller audioController,
    DownloaderController downloadController,
  ) {
    final downloadItem = DownloadItem(
      id: id,
      title: title,
      url: url!,
      type: DownloadType.narrations,
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StreamOrDownloadDialog(
        item: downloadItem,
        onStream: () {
          Navigator.of(dialogContext).pop();
          audioController.initPlayer(url!, title, false);
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

  Widget _buildDeleteButton(
      BuildContext context, DownloaderController downloadController) {
    return IconButton(
      onPressed: () => _showDeleteConfirmation(context, downloadController),
      icon: const Icon(Icons.delete_outline, size: 20),
      tooltip: 'حذف الملف المحمل',
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, DownloaderController downloadController) {
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
            onPressed: () {
              downloadController.deleteFile(id, DownloadType.narrations);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
