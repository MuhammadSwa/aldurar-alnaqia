import 'dart:async';

import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_status_widgets.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/widgets/stream_download_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class PlayAudioBtnZikrPage extends ConsumerWidget {
  const PlayAudioBtnZikrPage({
    required this.title, required this.url, required this.id, super.key,
    this.queue,
  });

  final String title;
  final String? url;
  final String id;

  /// Playlist context (e.g. the slidable azkar list). When provided, the
  /// mini player can auto-advance through it; each item streams automatically
  /// when not downloaded locally.
  final List<AudioTrack>? queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide while this zikr is loaded in the mini player (playing, paused,
    // loading, or error) — not just while actively playing.
    final isOpenForThisZikr = ref.watch(
      audioProvider.select((s) => s.isVisible && s.track?.id == id),
    );

    return DownloadStatusBuilder(
      item: DownloadItem(
        id: id,
        title: title,
        url: url ?? '',
        type: DownloadType.narrations,
      ),
      builder: (context, ref, downloader, isDownloading, isFileDownloaded) {
        if (url == null || isOpenForThisZikr) {
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
            onPressed: () => _play(ref),
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

  /// Single play path: the controller resolves the downloaded file first
  /// and streams automatically when it is missing locally.
  void _play(WidgetRef ref) {
    unawaited(
      ref.read(audioProvider.notifier).playTrack(
            AudioTrack(id: id, title: title, remoteUrl: url!),
            queue: queue,
          ),
    );
  }

  void _handleAudioTap(BuildContext context, WidgetRef ref) {
    if (url == null) return;
    final action = ref.read(fileOpenActionProvider);
    switch (action) {
      case FileOpenAction.open:
        _play(ref);
      case FileOpenAction.download:
        _downloadDirectly(ref);
      case FileOpenAction.ask:
        _showStreamDownloadDialog(context, ref);
    }
  }

  void _downloadDirectly(WidgetRef ref) {
    unawaited(
      ref.read(downloaderProvider).startDownload(
            DownloadItem(
              id: id,
              title: title,
              url: url!,
              type: DownloadType.narrations,
            ),
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

    unawaited(
      showStreamOrDownloadDialog(
        context: context,
        ref: ref,
        item: downloadItem,
        onOpen: () => _play(ref),
      ),
    );
  }
}
