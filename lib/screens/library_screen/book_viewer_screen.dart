import 'dart:async';

import 'package:aldurar_alnaqia/common/helpers/snackbar.dart';
import 'package:aldurar_alnaqia/common/widgets/app_pdf_view.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/screens/library_screen/book_temp_loader.dart';
import 'package:aldurar_alnaqia/screens/library_screen/books.dart';
import 'package:aldurar_alnaqia/screens/library_screen/widgets/book_error_view.dart';
import 'package:aldurar_alnaqia/screens/library_screen/widgets/book_jump_dialog.dart';
import 'package:aldurar_alnaqia/screens/library_screen/widgets/book_loading_view.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

/// Simple book reader: opens the downloaded file when it exists, otherwise
/// downloads the PDF to a temp file with progress and opens it.
///
/// Remembers the last page per book in [SharedPreferencesService].
class BookViewerScreen extends ConsumerStatefulWidget {
  const BookViewerScreen({required this.bookId, super.key});

  final String bookId;

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

  /// Immersive-reader chrome: visible on entry, auto-hides while reading.
  bool _chromeVisible = true;
  Timer? _chromeTimer;

  String get _id => widget.bookId;
  BookInfo? get _book => bookById(_id);
  String? get _url => _book?.url;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    // Always leave immersive mode: other screens expect edge-to-edge.
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _saveCurrentPage();
    unawaited(_document?.close());
    _controller?.dispose();
    super.dispose();
  }

  /// Shows the AppBar + status bar and (re)starts the auto-hide countdown.
  void _showChrome() {
    if (!mounted || _chromeVisible) {
      if (mounted) _restartHideTimer();
      return;
    }
    setState(() => _chromeVisible = true);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _restartHideTimer();
  }

  void _hideChrome() {
    if (!mounted || !_chromeVisible) return;
    _chromeTimer?.cancel();
    setState(() => _chromeVisible = false);
    unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),);
  }

  void _toggleChrome() {
    if (_chromeVisible) {
      _hideChrome();
    } else {
      _showChrome();
    }
  }

  /// Hides 3s after the last explicit show. Only runs while a document is
  /// actually readable — never over loading/error states.
  void _restartHideTimer() {
    _chromeTimer?.cancel();
    if (_controller == null || _error != null) return;
    _chromeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _chromeVisible) _hideChrome();
    });
  }

  /// Reading-intent signals: a drag/pinch or a page turn means the user is
  /// immersed, so hide immediately when visible, stay hidden otherwise.
  void _onReadingInteraction() {
    if (_chromeVisible) _hideChrome();
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

      if (await storage.exists(DownloadType.books, _id)) {
        isLocal = true;
        document = await PdfDocument.openFile(
            storage.pathFor(DownloadType.books, _id),);
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

        final cached = await BookTempLoader.tempFile(_id);
        final useCache = !freshDownload &&
            await cached.exists() &&
            await cached.length() > 0;
        if (useCache) {
          final file = await BookTempLoader.downloadToTemp(
            url: url,
            id: _id,
            fresh: freshDownload,
            onProgress: onProgress,
          );
          document = await PdfDocument.openFile(file.path);
        } else {
          setState(() => _isDownloading = true);
          try {
            final file = await BookTempLoader.downloadToTemp(
              url: url,
              id: _id,
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

      final lastPage = SharedPreferencesService.getPdfLastPage(_id) ?? 1;
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
          showSnackBar(context, 'تمت المتابعة من الصفحة $lastPage');
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
      unawaited(SharedPreferencesService.setPdfLastPage(_id, page));
    }
  }

  void _retry() {
    unawaited(_document?.close());
    _controller?.dispose();
    _document = null;
    unawaited(_open(freshDownload: !_isLocal));
  }

  void _downloadForOffline() {
    final url = _url;
    if (url == null) return;
    unawaited(
      ref.read(downloaderProvider).startDownload(
            DownloadItem(
              id: _id,
              title: _book?.fullTitle ?? _id,
              url: url,
              type: DownloadType.books,
            ),
          ),
    );
    showSnackBar(context, 'بدأ تحميل الكتاب للقراءة دون إنترنت');
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
      showSnackBar(context, 'رقم الصفحة يجب أن يكون بين 1 و $total');
      return;
    }
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.animateToPage(
        pageNumber: page,
        duration: const Duration(milliseconds: 300),
      );
    } catch (_) {
      if (!mounted) return;
      showSnackBar(context, 'تعذر الانتقال إلى الصفحة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // Body stays fullscreen behind the AppBar, so showing/hiding it
        // never resizes the pages — it just overlays for full immersion.
        extendBodyBehindAppBar: true,
        appBar: _chromeVisible
            ? AppBar(
                title: Text(
                  _book?.title ?? _id,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  if (_controller != null)
                    _PagePill(
                        controller: _controller!, onTap: _showJumpToPage,),
                  if (_controller != null && !_isLocal)
                    IconButton(
                      icon:
                          const Icon(Icons.download_for_offline_outlined),
                      tooltip: 'تحميل للقراءة دون إنترنت',
                      onPressed: _downloadForOffline,
                    ),
                ],
              )
            : null,
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
      onPageChanged: (page) {
        unawaited(SharedPreferencesService.setPdfLastPage(_id, page));
        _onReadingInteraction();
      },
      onDocumentLoaded: (_) {
        setState(() {});
        _restartHideTimer();
      },
      onDocumentError: (error) => setState(() => _error = error),
      // Single tap toggles chrome; drag/pinch is reading → hide.
      onTap: _toggleChrome,
      onInteractionStart: (_) => _onReadingInteraction(),
      onScrollbarDrag: _onReadingInteraction,
      documentLoaderBuilder: _buildLoading,
      errorBuilder: _buildError,
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
