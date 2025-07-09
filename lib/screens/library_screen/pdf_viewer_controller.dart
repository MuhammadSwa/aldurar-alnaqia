import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

// Assuming these imports are correct for your project structure
import 'package:aldurar_alnaqia/common/helpers/helpers.dart';
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

  // --- Non-reactive State ---
  // Used to temporarily hold the current text selection from the viewer
  List<PdfTextRanges>? textSelections;

  @override
  void onInit() {
    super.onInit();
    openDocument();
  }

  @override
  void onClose() {
    // Dispose all controllers and notifiers to prevent memory leaks.
    textSearcher.value?.dispose();
    // pdfController is managed by the PdfViewer widget and doesn't need disposal here.
    super.onClose();
  }

  // --- Logic and Handlers ---

  /// Opens the PDF document from a local file or a remote URL.
  Future<void> openDocument() async {
    final fileExists = await isFileDownloaded(title: title, directory: 'books');
    if (fileExists) {
      final appDir = await getApplicationSupportDirectory();
      final filePath =
          '${appDir.path}${Platform.pathSeparator}books${Platform.pathSeparator}$title.pdf';
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
