import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_status_widgets.dart';
import 'package:aldurar_alnaqia/widgets/stream_download_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final audio = ref.watch(audioProvider.select((s) => (
          playingId: s.isPlayingThisTrack ? s.track?.id : null,
        )));

    return DownloadStatusBuilder(
      item: DownloadItem(
        id: id,
        title: title,
        url: url ?? '',
        type: DownloadType.narrations,
      ),
      builder: (context, ref, downloader, isDownloading, isFileDownloaded) {
        final isPlayingThisUrl = audio.playingId == id;

        if (url == null || isPlayingThisUrl) {
          return Container();
        }

        if (isDownloading) {
          final progressNotifier = downloader.progressNotifierFor(id);
          return progressNotifier != null
              ? DownloadProgressIcon(
                  progressNotifier: progressNotifier,
                  onCancel: () =>
                      downloader.cancelDownload(id, DownloadType.narrations),
                  size: 40,
                  iconSize: 16,
                )
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
          onPressed: () => _handleAudioTap(context, ref),
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

  void _handleAudioTap(BuildContext context, WidgetRef ref) {
    if (url == null) return;
    final action = ref.read(fileOpenActionProvider);
    switch (action) {
      case FileOpenAction.open:
        _streamDirectly(ref);
        break;
      case FileOpenAction.download:
        _downloadDirectly(ref);
        break;
      case FileOpenAction.ask:
        _showStreamDownloadDialog(context, ref);
        break;
    }
  }

  void _streamDirectly(WidgetRef ref) {
    ref.read(audioProvider.notifier).playTrack(
          AudioTrack(id: id, title: title, remoteUrl: url!),
        );
  }

  void _downloadDirectly(WidgetRef ref) {
    ref.read(downloaderProvider).startDownload(
          DownloadItem(
            id: id,
            title: title,
            url: url!,
            type: DownloadType.narrations,
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

    showStreamOrDownloadDialog(
      context: context,
      ref: ref,
      item: downloadItem,
      onOpen: () => ref.read(audioProvider.notifier).playTrack(
            AudioTrack(id: id, title: title, remoteUrl: url!),
          ),
    );
  }
}
