import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared download-state wiring: `ensureKnown` + rebuild on
/// `statusRevision`, exposing `isDownloading` / `isDownloaded`.
///
/// Replaces the triplicated blocks in `LibraryScreen`, `DownloadManagerTile`
/// and `PlayAudioBtnZikrPage`.
class DownloadStatusBuilder extends ConsumerWidget {
  const DownloadStatusBuilder({
    super.key,
    required this.item,
    required this.builder,
  });

  final DownloadItem item;
  final Widget Function(
    BuildContext context,
    WidgetRef ref,
    DownloaderService downloader,
    bool isDownloading,
    bool isDownloaded,
  ) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloader = ref.watch(downloaderProvider);
    // Trigger a coalesced status check (safe to call on every build).
    downloader.ensureKnown(item.id, item.type);
    return ValueListenableBuilder<int>(
      valueListenable: downloader.statusRevision,
      builder: (context, _, __) {
        return builder(
          context,
          ref,
          downloader,
          downloader.isDownloading(item.id),
          downloader.cachedStatus(item.id, item.type) ?? false,
        );
      },
    );
  }
}

/// Shared progress indicator with cancel button for download tiles.
class DownloadProgressIcon extends StatelessWidget {
  const DownloadProgressIcon({
    super.key,
    required this.progressNotifier,
    required this.onCancel,
    this.size = 32,
    this.iconSize = 18,
  });

  final ValueNotifier<double> progressNotifier;
  final VoidCallback onCancel;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: progressNotifier,
      builder: (context, progress, child) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(value: progress, strokeWidth: 2.5),
              IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.close, size: iconSize),
                onPressed: onCancel,
                tooltip: 'إلغاء التحميل',
              ),
            ],
          ),
        );
      },
    );
  }
}
