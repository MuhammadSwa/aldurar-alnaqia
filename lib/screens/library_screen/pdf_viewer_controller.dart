
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/screens/library_screen/library_screen.dart';
import 'package:aldurar_alnaqia/screens/library_screen/pdfViewer/markers_view.dart';
import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';

/// Owns the state of one open PDF viewer (per book title).
/// Plain [ChangeNotifier] so it stays framework-independent; the owning
/// widget listens via [ListenableBuilder] and disposes it on close.
class BookViewerController extends ChangeNotifier {
  BookViewerController({required this.title, required StorageService storage})
      : _storage = storage {
    openDocument();
  }

  final String title;
  final StorageService _storage;

  // --- Controllers from packages ---
  final pdfController = PdfViewerController();

  // --- Observable State ---
  PdfDocumentRef? documentRef;
  bool showSidePane = false;
  List<PdfOutlineNode>? outline;
  PdfTextSearcher? textSearcher;
  bool isViewerReady = false;
  final Map<int, List<Marker>> markers = {};
  // The page number we resumed from (if any) when the viewer restores
  int? resumedFromPage;

  // --- Non-observable State ---
  // Used to temporarily hold the current text selection from the viewer
  List<PdfTextRanges>? textSelections;

  // Track listener attachment to avoid duplicates
  bool _pageListenerAttached = false;
  int? _lastKnownPage;

  @override
  void dispose() {
    // Dispose all controllers and notifiers to prevent memory leaks.
    textSearcher?.dispose();
    // Detach page change listener to avoid duplicate callbacks on next open
    if (_pageListenerAttached) {
      pdfController.removeListener(_onPdfControllerChanged);
      _pageListenerAttached = false;
    }
    // Persist one last time on close using last known page only to avoid
    // touching PdfViewerController internal state after widget teardown.
    final page = _lastKnownPage;
    if (page != null) {
      SharedPreferencesService.setPdfLastPage(title, page);
    }
    super.dispose();
  }

  void toggleSidePane() {
    showSidePane = !showSidePane;
    notifyListeners();
  }

  /// Opens the PDF document from a local file or a remote URL.
  Future<void> openDocument() async {
    final fileExists = await _storage.exists(DownloadType.books, title);
    if (fileExists) {
      documentRef =
          PdfDocumentRefFile(_storage.pathFor(DownloadType.books, title));
    } else {
      final url = booksTitles[title];
      if (url != null) {
        documentRef = PdfDocumentRefUri(Uri.parse(url));
      }
    }
    notifyListeners();
  }

  /// Callback when a new document is loaded into the viewer.
  void onDocumentChanged(PdfDocument? document) {
    isViewerReady = false; // Reset ready state
    if (document == null) {
      textSearcher?.dispose();
      textSearcher = null;
      outline = null;
      textSelections = null;
      markers.clear();
    }
    notifyListeners();
  }

  /// Callback when the viewer has finished loading and is ready for interaction.
  Future<void> onViewerReady(
      PdfDocument document, PdfViewerController controller) async {
    outline = await document.loadOutline();
    textSearcher = PdfTextSearcher(controller);
    // Setting this to true will enable UI elements like navigation buttons
    isViewerReady = true;

    // Jump to last visited page if available
    final last = SharedPreferencesService.getPdfLastPage(title);
    if (last != null && last >= 1 && last <= controller.pageCount) {
      // Use post-frame to ensure viewport/layout ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.goToPage(pageNumber: last);
      });
      _lastKnownPage = last;
      // Notify UI to optionally show a resume hint
      resumedFromPage = last;
    }
    // Start listening for page changes to persist
    _attachPageChangeListener();
    notifyListeners();
  }

  void _attachPageChangeListener() {
    if (!_pageListenerAttached) {
      pdfController.addListener(_onPdfControllerChanged);
      _pageListenerAttached = true;
    }
  }

  /// Expose a safe way to detach the listener when the widget disposes.
  void detachPageChangeListener() {
    if (_pageListenerAttached) {
      pdfController.removeListener(_onPdfControllerChanged);
      _pageListenerAttached = false;
    }
  }

  void _onPdfControllerChanged() {
    if (!pdfController.isReady) return;
    final page = pdfController.pageNumber;
    if (page != null) {
      _lastKnownPage = page;
      SharedPreferencesService.setPdfLastPage(title, page);
    }
  }

  /// Adds the currently selected text to the list of markers.
  void addCurrentSelectionToMarkers(Color color) {
    if (pdfController.isReady && textSelections != null) {
      for (final selection in textSelections!) {
        // Get the list for the page, or create it if it doesn't exist
        final pageMarkers =
            markers.putIfAbsent(selection.pageNumber, () => []);
        pageMarkers.add(Marker(color, selection));
      }
      textSelections = null; // Clear selection after marking
      notifyListeners();
    }
  }

  /// Removes a marker.
  void removeMarker(Marker marker) {
    markers[marker.ranges.pageNumber]?.remove(marker);
    notifyListeners();
  }

  /// Shows a confirmation dialog before navigating to an external URL.
  Future<void> showUrlNavigateDialog(
      BuildContext context, Uri url) async {
    final shouldLaunch = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الانتقال إلى الرابط؟'),
        content: Text.rich(
          TextSpan(
            text: 'هل تريد الانتقال إلى الموقع التالي؟\n\n',
            children: [
              TextSpan(
                text: url.toString(),
                style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline),
              ),
            ],
          ),
          textDirection: TextDirection.ltr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('انتقال'),
          ),
        ],
      ),
    );

    if (shouldLaunch == true) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
