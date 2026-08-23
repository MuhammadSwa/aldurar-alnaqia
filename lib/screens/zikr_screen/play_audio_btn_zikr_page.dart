import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/widgets/stream_download_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/router/nav_helpers.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

class PlayAudioBtnZikrPage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final downloader = ref.watch(downloaderProvider);
    final audio = ref.watch(audioProvider.select((s) => (
          playingId: s.isPlayingThisTrack ? s.track?.id : null,
        )));

    // Trigger a coalesced status check (safe to call on every build).
    downloader.ensureKnown(id, DownloadType.narrations);

    return ValueListenableBuilder<int>(
      // Rebuild on download-state changes (started / completed / deleted).
      valueListenable: downloader.statusRevision,
      builder: (context, _, __) {
        final isPlayingThisUrl = audio.playingId == id;
        final isFileDownloaded = downloader.cachedStatus(id) ?? false;
        final isDownloading = downloader.isDownloading(id);

        if (url == null || isPlayingThisUrl) {
          return Container();
        }

        if (isDownloading) {
          final progressNotifier = downloader.progressNotifierFor(id);
          return progressNotifier != null
              ? _buildProgressIndicator(
                  progressNotifier, () => downloader.cancelDownload(id))
              : const SizedBox.shrink();
        }

        if (isFileDownloaded) {
          return IconButton(
            onPressed: () => _playLocally(ref),
            icon: const Icon(Icons.volume_up),
            tooltip: 'تشغيل الصوت (محلي)',
          );
        }

        return IconButton(
          onPressed: () => _showStreamDownloadDialog(context, ref),
          icon: const Icon(Icons.volume_up),
          tooltip: 'استماع أو تحميل الصوت',
        );
      },
    );
  }

  void _playLocally(WidgetRef ref) {
    ref.read(audioProvider.notifier).playTrack(
          AudioTrack(
            id: id,
            title: title,
            remoteUrl: url!,
          ),
        );
  }

  void _showStreamDownloadDialog(BuildContext context, WidgetRef ref) {
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
            ref.read(audioProvider.notifier).playTrack(
                  AudioTrack(id: id, title: title, remoteUrl: url!),
                );
          },
          onDownload: () {
            Navigator.of(dialogContext).pop();
            ref.read(downloaderProvider).startDownload(downloadItem);
          },
          onManageDownloads: () {
            Navigator.of(dialogContext).pop();
            AppNav.goToDownloadManager(context, 0);
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
