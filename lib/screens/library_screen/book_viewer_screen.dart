import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
// NOTE: same viewer API as pdfx_lite (PdfDocument / PdfControllerPinch /
// PdfViewPinch). Switch this import to `package:pdfx_lite/pdfx_lite.dart`
// once the project upgrades to Flutter >=3.47.
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/screens/library_screen/books.dart';
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
        final file = await _downloadToTemp(url, fresh: freshDownload);
        document = await PdfDocument.openFile(file.path);
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

  /// Downloads [url] to the temp dir, reporting progress via setState.
  /// Timeouts apply to connect/headers only; slow bodies keep streaming.
  Future<File> _downloadToTemp(String url, {bool fresh = false}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/online_${_title.hashCode}.pdf');

    if (!fresh && await file.exists() && await file.length() > 0) {
      return file;
    }

    setState(() => _isDownloading = true);
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('فشل التحميل (${response.statusCode})');
      }

      final total =
          response.contentLength > 0 ? response.contentLength : null;
      final tmp = File('${file.path}.part');
      final sink = tmp.openWrite();
      var received = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (mounted) {
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        }
      } finally {
        await sink.close();
      }
      await tmp.rename(file.path);
      return file;
    } finally {
      client.close();
      if (mounted) setState(() => _isDownloading = false);
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
  /// drives the viewer. Mutating the viewer while the dialog route is still
  /// in the tree trips `'_dependents.isEmpty'` deactivation asserts, so the
  /// dialog must be awaited — never animate on a stale modal context.
  Future<void> _pickPageAndJump(int total) async {
    final textController = TextEditingController(
      text: _controller?.page.toString() ?? '1',
    );
    try {
      // NOTE: showDialog pushes onto the ROOT navigator while this screen
      // lives on a shell-branch navigator, so the dialog is closed via
      // [dialogContext] and returns the parsed page (or null).
      final page = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('الانتقال إلى صفحة', textAlign: TextAlign.center),
          content: TextField(
            controller: textController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'من 1 إلى $total',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => Navigator.of(dialogContext)
                .pop(_parsePage(textController.text)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(_parsePage(textController.text)),
              child: const Text('انتقال'),
            ),
          ],
        ),
      );
      if (page == null || !mounted) return;
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
    } finally {
      textController.dispose();
    }
  }

  static int? _parsePage(String raw) => int.tryParse(raw.trim());

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
    return PdfViewPinch(
      controller: controller,
      scrollDirection: Axis.vertical,
      padding: 8,
      onPageChanged: (page) =>
          unawaited(SharedPreferencesService.setPdfLastPage(_title, page)),
      onDocumentLoaded: (_) => setState(() {}),
      onDocumentError: (error) => setState(() => _error = error),
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => _buildLoading(),
        pageLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, error) => _buildError(error),
      ),
    );
  }

  Widget _buildLoading() {
    final downloadedMb = (_receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = _totalBytes != null
        ? (_totalBytes! / (1024 * 1024)).toStringAsFixed(1)
        : null;
    final progress = _totalBytes != null && _totalBytes! > 0
        ? _receivedBytes / _totalBytes!
        : null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: progress),
          const SizedBox(height: 16),
          Text(
            _isDownloading
                ? (totalMb != null
                    ? 'جاري تحميل الكتاب... $downloadedMb / $totalMb م.ب'
                    : 'جاري تحميل الكتاب... $downloadedMb م.ب')
                : 'جاري فتح الكتاب...',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError([Object? error]) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'تعذّر فتح الكتاب',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'تحقق من الاتصال بالإنترنت وحاول مجددًا، أو حمّل الكتاب للقراءة دون إنترنت.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
                OutlinedButton.icon(
                  onPressed: _downloadForOffline,
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: const Text('تحميل للقراءة دون إنترنت'),
                ),
                TextButton.icon(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('فتح في المتصفح'),
                ),
              ],
            ),
          ],
        ),
      ),
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
