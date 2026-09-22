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

  DownloadItem buildItem() => DownloadItem(
        id: id,
        title: title,
        url: url ?? '',
        type: DownloadType.narrations,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (url == null) return const SizedBox.shrink();

    // Hide while this zikr is loaded in the mini player (playing, paused,
    // loading, or error) — not just while actively playing.
    final isOpenForThisZikr = ref.watch(
      audioProvider.select((s) => s.isVisible && s.track?.id == id),
    );

    final item = buildItem();

    return DownloadStatusBuilder(
      item: item,
      builder: (context, ref, downloader, isDownloading, isFileDownloaded) {
        if (isOpenForThisZikr) return const SizedBox.shrink();

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

        // One play path for both cases: the controller prefers the
        // downloaded file automatically and falls back to streaming.
        final tooltip =
            isFileDownloaded ? 'تشغيل الصوت (محلي)' : 'استماع أو تحميل الصوت';

        if (isFileDownloaded ||
            ref.read(fileOpenActionProvider) == FileOpenAction.open) {
          return IconButton(
            onPressed: () => _play(ref),
            icon: const Icon(Icons.volume_up),
            tooltip: tooltip,
          );
        }

        final action = ref.read(fileOpenActionProvider);
        if (action == FileOpenAction.download) {
          return IconButton(
            onPressed: () => unawaited(
              ref.read(downloaderProvider).startDownload(buildItem()),
            ),
            icon: const Icon(Icons.volume_up),
            tooltip: tooltip,
          );
        }

        return IconButton(
          onPressed: () => unawaited(
            showStreamOrDownloadDialog(
              context: context,
              ref: ref,
              item: item,
              onOpen: () => _play(ref),
            ),
          ),
          icon: const Icon(Icons.volume_up),
          tooltip: tooltip,
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
}
