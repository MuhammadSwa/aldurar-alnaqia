import 'package:aldurar_alnaqia/common/widgets/app_tile.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_status_widgets.dart';
import 'package:aldurar_alnaqia/screens/library_screen/books.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/widgets/stream_download_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/router/nav_helpers.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';

// Book catalogue lives in books.dart; the viewer looks the url up itself,
// so this screen only deals with titles and download state.

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المكتبة'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () =>
              ref.read(rootScaffoldKeyProvider).currentState?.openDrawer(),
          tooltip: 'فتح القائمة',
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: books.length,
        itemBuilder: (context, index) {
          return _BookListTile(book: books[index]);
        },
      ),
    );
  }
}

class _BookListTile extends ConsumerWidget {
  const _BookListTile({required this.book});

  final BookInfo book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = DownloadItem(
      id: book.id,
      title: book.fullTitle,
      url: book.url,
      type: DownloadType.books,
    );
    return DownloadStatusBuilder(
      item: item,
      builder: (context, ref, downloader, isDownloading, isDownloaded) {
        return AppTile(
          // Full name, title-only: it wraps to two lines.
          title: book.fullTitle,
          maxTitleLines: 2,
          leading: _buildLeadingIcon(
            isDownloading: isDownloading,
            isDownloaded: isDownloaded,
            progressNotifier: downloader.progressNotifierFor(item.id),
            onCancel: () => downloader.cancelDownload(item.id, item.type),
          ),
          onTap: () => _handleTap(context, ref, isDownloaded),
        );
      },
    );
  }

  Widget _buildLeadingIcon({
    required bool isDownloading,
    required bool isDownloaded,
    required ValueNotifier<double>? progressNotifier,
    required VoidCallback onCancel,
  }) {
    if (isDownloading && progressNotifier != null) {
      return DownloadProgressIcon(
        progressNotifier: progressNotifier,
        onCancel: onCancel,
        size: 42,
      );
    }

    return AppTileLeadingIcon(
      icon: isDownloaded ? Icons.menu_book_rounded : Icons.cloud_outlined,
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref, bool isDownloaded) {
    if (isDownloaded) {
      // Open viewer; it will auto-restore last page.
      AppNav.goToPdfViewer(context, book.id);
      return;
    }
    final action = ref.read(fileOpenActionProvider);
    switch (action) {
      case FileOpenAction.open:
        AppNav.goToPdfViewer(context, book.id);
        break;
      case FileOpenAction.download:
        ref.read(downloaderProvider).startDownload(
              DownloadItem(
                id: book.id,
                title: book.fullTitle,
                url: book.url,
                type: DownloadType.books,
              ),
            );
        break;
      case FileOpenAction.ask:
        _showDownloadOptionsDialog(context, ref);
        break;
    }
  }

  void _showDownloadOptionsDialog(BuildContext context, WidgetRef ref) {
    showStreamOrDownloadDialog(
      context: context,
      ref: ref,
      item: DownloadItem(
        id: book.id,
        title: book.fullTitle,
        url: book.url,
        type: DownloadType.books,
      ),
      onOpen: () => AppNav.goToPdfViewer(context, book.id),
    );
  }
}
