
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';

// Assuming these imports are correct for your project structure
// import 'package:aldurar_alnaqia/common/helpers/helpers.dart';
import 'package:aldurar_alnaqia/screens/library_screen/library_screen.dart';
import 'package:aldurar_alnaqia/screens/library_screen/pdfViewer/markers_view.dart';

class PdfViewerGetxController extends GetxController {
  // Constructor to receive the book title
  final String title;
  PdfViewerGetxController({required this.title});

  // --- Controllers from packages ---
  final pdfController = PdfViewerController();

  // --- Reactive State Variables ---
  final documentRef = Rxn<PdfDocumentRef>();
  final showSidePane = false.obs;
  final outline = Rxn<List<PdfOutlineNode>>();
  final textSearcher = Rxn<PdfTextSearcher>();
  final isViewerReady = false.obs;
  final markers = <int, List<Marker>>{}.obs;
  // Emits the page number we resumed from (if any) when the viewer restores
  final resumedFromPage = Rxn<int>();

  // --- Non-reactive State ---
  // Used to temporarily hold the current text selection from the viewer
  List<PdfTextRanges>? textSelections;

  // Track listener attachment to avoid duplicates
  bool _pageListenerAttached = false;
  int? _lastKnownPage;

  @override
  void onInit() {
    super.onInit();
    openDocument();
  // Restore last page after controller ready (handled in onViewerReady)
  }

  @override
  void onClose() {
    // Dispose all controllers and notifiers to prevent memory leaks.
    textSearcher.value?.dispose();
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
    super.onClose();
  }

  // --- Logic and Handlers ---

  /// Opens the PDF document from a local file or a remote URL.
  Future<void> openDocument() async {
  final storage = Get.find<StorageService>();
  final fileExists = await storage.exists(DownloadType.books, title);
  if (fileExists) {
      final filePath = storage.pathFor(DownloadType.books, title);
      documentRef.value = PdfDocumentRefFile(filePath);
    } else {
      final url = booksTitles[title];
      if (url != null) {
        documentRef.value = PdfDocumentRefUri(Uri.parse(url));
      }
    }
  }

  /// Callback when a new document is loaded into the viewer.
  void onDocumentChanged(PdfDocument? document) {
    isViewerReady.value = false; // Reset ready state
    if (document == null) {
      textSearcher.value?.dispose();
      textSearcher.value = null;
      outline.value = null;
      textSelections = null;
      markers.clear();
    }
  }

  /// Callback when the viewer has finished loading and is ready for interaction.
  Future<void> onViewerReady(
      PdfDocument document, PdfViewerController controller) async {
    outline.value = await document.loadOutline();
    textSearcher.value = PdfTextSearcher(controller);
    // Setting this to true will enable UI elements like navigation buttons
    isViewerReady.value = true;

  // Jump to last visited page if available
    final last = SharedPreferencesService.getPdfLastPage(title);
    if (last != null && last >= 1 && last <= controller.pageCount) {
      // Use post-frame to ensure viewport/layout ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.goToPage(pageNumber: last);
      });
      _lastKnownPage = last;
  // Notify UI to optionally show a resume hint
  resumedFromPage.value = last;
    }
    // Start listening for page changes to persist
    _attachPageChangeListener();
  }

  void _attachPageChangeListener() {
    // PdfViewerController exposes pageNumber; poll via listener on changes
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
        final pageMarkers = markers.putIfAbsent(selection.pageNumber, () => []);
        pageMarkers.add(Marker(color, selection));

        // Use a temporary variable and reassign to trigger RxMap update
        final updatedMarkers = Map<int, List<Marker>>.from(markers);
        updatedMarkers[selection.pageNumber] = pageMarkers;
        markers.assignAll(updatedMarkers);
      }
      textSelections = null; // Clear selection after marking
    }
  }

  /// Shows a confirmation dialog before navigating to an external URL.
  Future<void> showUrlNavigateDialog(Uri url) async {
    final context = Get.context!;
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
                    color: Colors.blue, decoration: TextDecoration.underline),
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
