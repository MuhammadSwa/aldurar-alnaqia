import 'dart:async';

import 'package:aldurar_alnaqia/common/widgets/app_pdf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/screens/library_screen/book_temp_loader.dart';
import 'package:aldurar_alnaqia/screens/library_screen/books.dart';
import 'package:aldurar_alnaqia/screens/library_screen/widgets/book_error_view.dart';
import 'package:aldurar_alnaqia/screens/library_screen/widgets/book_jump_dialog.dart';
import 'package:aldurar_alnaqia/screens/library_screen/widgets/book_loading_view.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

/// Simple book reader: opens the downloaded file when it exists, otherwise
/// downloads the PDF to a temp file with progress and opens it.
///
/// Remembers the last page per book title in [SharedPreferencesService].
class BookViewerScreen extends ConsumerStatefulWidget {
  const BookViewerScreen({super.key, required this.title});

  final String title;

  @override
  ConsumerState<BookViewerScreen> createState() => _BookViewerScreenState();
}

class _BookViewerScreenState extends ConsumerState<BookViewerScreen> {
  PdfControllerPinch? _controller;
  PdfDocument? _document;
  Object? _error;
  bool _isLocal = false;
  bool _isDownloading = false;
  int _receivedBytes = 0;
  int? _totalBytes;

  String get _title => widget.title;
  String? get _url => booksTitles[_title];

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _saveCurrentPage();
    unawaited(_document?.close());
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _open({bool freshDownload = false}) async {
    setState(() {
      _controller = null;
      _error = null;
      _isDownloading = false;
      _receivedBytes = 0;
      _totalBytes = null;
    });

    final url = _url;
    if (url == null) {
      setState(() => _error = StateError('الكتاب غير معروف'));
      return;
    }

    try {
      final storage = ref.read(storageProvider);
      late final PdfDocument document;
      var isLocal = false;

      if (await storage.exists(DownloadType.books, _title)) {
        isLocal = true;
        document =
            await PdfDocument.openFile(storage.pathFor(DownloadType.books, _title));
      } else {
        // NOTE: temp previews intentionally stay on foreground HttpClient via
        // [BookTempLoader] and do NOT use `background_downloader`. The offline
        // flow below (`_downloadForOffline` via `downloaderProvider`) already
        // owns the background-download path; previews need a plain File path
        // with inline progress, not a background task callback.
        //
        // Mirror the original `_downloadToTemp` behavior: a cached temp hit
        // never flips [_isDownloading] (loading text stays "جاري فتح الكتاب...").
        void onProgress(int received, int? total) {
          if (mounted) {
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        }

        final cached = await BookTempLoader.tempFile(_title);
        final useCache = !freshDownload &&
            await cached.exists() &&
            await cached.length() > 0;
        if (useCache) {
          final file = await BookTempLoader.downloadToTemp(
            url: url,
            title: _title,
            fresh: freshDownload,
            onProgress: onProgress,
          );
          document = await PdfDocument.openFile(file.path);
        } else {
          setState(() => _isDownloading = true);
          try {
            final file = await BookTempLoader.downloadToTemp(
              url: url,
              title: _title,
              fresh: freshDownload,
              onProgress: onProgress,
            );
            document = await PdfDocument.openFile(file.path);
          } finally {
            if (mounted) setState(() => _isDownloading = false);
          }
        }
      }

      if (!mounted) {
        unawaited(document.close());
        return;
      }

      final lastPage = SharedPreferencesService.getPdfLastPage(_title) ?? 1;
      final controller = PdfControllerPinch(
        document: Future.value(document),
        initialPage: lastPage,
      );

      setState(() {
        _document = document;
        _controller = controller;
        _isLocal = isLocal;
      });

      if (lastPage > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..removeCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('تمت المتابعة من الصفحة $lastPage')),
            );
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _saveCurrentPage() {
    // NOTE: read pageListenable, NOT controller.page — the latter touches
    // PdfViewPinch internals (_state!) which are already detached when this
    // State disposes (children unmount first), crashing with Null check.
    final page = _controller?.pageListenable.value;
    if (page != null && page > 0) {
      unawaited(SharedPreferencesService.setPdfLastPage(_title, page));
    }
  }

  void _retry() {
    unawaited(_document?.close());
    _controller?.dispose();
    _document = null;
    _open(freshDownload: !_isLocal);
  }

  void _downloadForOffline() {
    final url = _url;
    if (url == null) return;
    ref.read(downloaderProvider).startDownload(DownloadItem(
          id: _title,
          title: _title,
          url: url,
          type: DownloadType.books,
        ));
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('بدأ تحميل الكتاب للقراءة دون إنترنت')),
      );
  }

  Future<void> _openInBrowser() async {
    final url = _url;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _showJumpToPage() {
    final controller = _controller;
    final total = controller?.pagesCount;
    if (controller == null || total == null) return;
    unawaited(_pickPageAndJump(total));
  }

  /// Shows the jump dialog, waits until it is fully dismissed, and only then
  /// drives the viewer. Animating the PdfView in the same frame as the
  /// dialog pop trips `'_dependents.isEmpty'` deactivation asserts, so we
  /// let the dialog route (and keyboard focus) settle first.
  Future<void> _pickPageAndJump(int total) async {
    final page = await showBookJumpDialog(
      context,
      currentPage: _controller?.page ?? 1,
      total: total,
    );
    if (!mounted) return;
    // Let the dialog's exit animation + focus release finish before
    // touching the PdfView or ScaffoldMessenger.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    if (page == null) return;
    if (page < 1 || page > total) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('رقم الصفحة يجب أن يكون بين 1 و $total')),
        );
      return;
    }
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.animateToPage(
        pageNumber: page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('تعذر الانتقال إلى الصفحة')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title, overflow: TextOverflow.ellipsis),
          actions: [
            if (_controller != null)
              _PagePill(controller: _controller!, onTap: _showJumpToPage),
            if (_controller != null && !_isLocal)
              IconButton(
                icon: const Icon(Icons.download_for_offline_outlined),
                tooltip: 'تحميل للقراءة دون إنترنت',
                onPressed: _downloadForOffline,
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) return _buildError();
    final controller = _controller;
    if (controller == null) return _buildLoading();
    return AppPdfView(
      controller: controller,
      padding: 8,
      onPageChanged: (page) =>
          unawaited(SharedPreferencesService.setPdfLastPage(_title, page)),
      onDocumentLoaded: (_) => setState(() {}),
      onDocumentError: (error) => setState(() => _error = error),
      documentLoaderBuilder: _buildLoading,
      errorBuilder: (error) => _buildError(error),
    );
  }

  Widget _buildLoading() {
    return BookLoadingView(
      received: _receivedBytes,
      total: _totalBytes,
      isDownloading: _isDownloading,
    );
  }

  Widget _buildError([Object? error]) {
    return BookErrorView(
      onRetry: _retry,
      onDownloadOffline: _downloadForOffline,
      onOpenBrowser: () => unawaited(_openInBrowser()),
    );
  }
}

/// Small page indicator in the AppBar; tap to jump to a page.
class _PagePill extends StatelessWidget {
  const _PagePill({required this.controller, required this.onTap});

  final PdfControllerPinch controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PdfPageNumber(
      controller: controller,
      builder: (_, loadingState, page, pagesCount) {
        if (loadingState != PdfLoadingState.success) {
          return const SizedBox.shrink();
        }
        return ActionChip(
          label: Text('$page / ${pagesCount ?? '…'}'),
          avatar: const Icon(Icons.book_outlined, size: 18),
          tooltip: 'الانتقال إلى صفحة',
          onPressed: onTap,
        );
      },
    );
  }
}
