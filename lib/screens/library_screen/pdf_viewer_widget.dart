import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

// Assuming these imports are correct for your project structure
import 'package:aldurar_alnaqia/common/helpers/helpers.dart';
import 'package:aldurar_alnaqia/screens/library_screen/library_screen.dart';
import 'package:aldurar_alnaqia/screens/library_screen/pdfViewer/markers_view.dart';
import 'package:aldurar_alnaqia/screens/library_screen/pdfViewer/outline_view.dart';
import 'package:aldurar_alnaqia/screens/library_screen/pdfViewer/search_view.dart';
import 'package:aldurar_alnaqia/screens/library_screen/pdfViewer/thumbnails_view.dart';

class PdfviewerWidget extends StatefulWidget {
  const PdfviewerWidget({super.key, required this.title});
  final String title;

  @override
  State<PdfviewerWidget> createState() => _PdfviewerWidgetState();
}

class _PdfviewerWidgetState extends State<PdfviewerWidget>
    with WidgetsBindingObserver {
  // --- State Management ---
  // Using ValueNotifier to efficiently update parts of the UI without full rebuilds.
  final _documentRef = ValueNotifier<PdfDocumentRef?>(null);
  final _showSidePane = ValueNotifier<bool>(false);
  final _outline = ValueNotifier<List<PdfOutlineNode>?>(null);
  final _textSearcher = ValueNotifier<PdfTextSearcher?>(null);

  final _controller = PdfViewerController();
  final _markers = <int, List<Marker>>{};
  List<PdfTextRanges>? _textSelections;

  // A getter to check if the device has a small screen.
  bool get _isMobileDevice => MediaQuery.of(context).size.shortestSide < 600;

  @override
  void initState() {
    super.initState();
    // Listen to app lifecycle events (e.g., for screen rotation).
    WidgetsBinding.instance.addObserver(this);
    _openDocument();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dispose all controllers and notifiers to prevent memory leaks.
    _textSearcher.value?.dispose();
    _textSearcher.dispose();
    _showSidePane.dispose();
    _outline.dispose();
    _documentRef.dispose();
    // _controller.dispose();
    super.dispose();
  }

  /// Handles screen orientation changes.
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Rebuild UI on screen rotation to adjust layout.
    if (mounted) {
      setState(() {});
    }
  }

  /// Main build method, organized into smaller parts.
  @override
  Widget build(BuildContext context) {
    // Directionality ensures the layout is RTL for Arabic.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Row(
          children: [
            _buildSidePane(),
            _buildPdfViewer(),
          ],
        ),
      ),
    );
  }

  // --- UI Builder Methods ---

  /// Builds the top application bar.
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      // The menu icon is on the right in RTL.
      leading: IconButton(
        tooltip: 'القائمة',
        icon: const Icon(Icons.menu),
        onPressed: () => _showSidePane.value = !_showSidePane.value,
      ),
      title: ValueListenableBuilder(
        valueListenable: _documentRef,
        builder: (context, docRef, child) {
          return Text(
            _fileName(docRef?.sourceName) ?? 'عارض الكتب',
            overflow: TextOverflow.ellipsis,
          );
        },
      ),
      actions: [
        _buildAppBarActions(),
      ],
    );
  }

  /// Builds the action buttons for the AppBar.
  Widget _buildAppBarActions() {
    return ValueListenableBuilder(
      valueListenable: _documentRef,
      builder: (context, docRef, child) {
        final isDocumentLoaded = docRef != null;
        final visualDensity = _isMobileDevice ? VisualDensity.compact : null;

        return Row(
          children: [
            // Marker Buttons
            _buildMarkerButton(
              color: Colors.red,
              tooltip: 'إضافة علامة حمراء',
              isEnabled: isDocumentLoaded,
              visualDensity: visualDensity,
            ),
            _buildMarkerButton(
              color: Colors.green,
              tooltip: 'إضافة علامة خضراء',
              isEnabled: isDocumentLoaded,
              visualDensity: visualDensity,
            ),
            _buildMarkerButton(
              color: Colors.orangeAccent,
              tooltip: 'إضافة علامة برتقالية',
              isEnabled: isDocumentLoaded,
              visualDensity: visualDensity,
            ),
            const VerticalDivider(width: 20, indent: 10, endIndent: 10),
            // Zoom Buttons
            _buildIconButton(
              icon: Icons.zoom_in,
              tooltip: 'تكبير',
              isEnabled: isDocumentLoaded,
              visualDensity: visualDensity,
              onPressed: () => _controller.zoomUp(),
            ),
            _buildIconButton(
              icon: Icons.zoom_out,
              tooltip: 'تصغير',
              isEnabled: isDocumentLoaded,
              visualDensity: visualDensity,
              onPressed: () => _controller.zoomDown(),
            ),
            const VerticalDivider(width: 20, indent: 10, endIndent: 10),
            // Navigation Buttons
            _buildIconButton(
              icon: Icons.first_page,
              tooltip: 'الصفحة الأولى',
              isEnabled: isDocumentLoaded,
              visualDensity: visualDensity,
              onPressed: () => _controller.goToPage(pageNumber: 1),
            ),
            _buildIconButton(
              icon: Icons.last_page,
              tooltip: 'الصفحة الأخيرة',
              isEnabled: isDocumentLoaded,
              visualDensity: visualDensity,
              onPressed: () =>
                  _controller.goToPage(pageNumber: _controller.pageCount),
            ),
            const SizedBox(width: 8),
          ],
        );
      },
    );
  }

  /// Builds the collapsible side pane for search, outline, etc.
  Widget _buildSidePane() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: ValueListenableBuilder(
        valueListenable: _showSidePane,
        builder: (context, isPaneVisible, child) {
          return SizedBox(
            width: isPaneVisible && !_isMobileDevice
                ? 320
                : (isPaneVisible && _isMobileDevice
                    ? MediaQuery.sizeOf(context).width * 0.8
                    : 0),
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 1, 0),
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.search), text: 'بحث'),
                    Tab(icon: Icon(Icons.menu_book), text: 'فهرس'),
                    Tab(icon: Icon(Icons.image), text: 'صفحات'),
                    Tab(icon: Icon(Icons.bookmark), text: 'علامات'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Search View
                      ValueListenableBuilder(
                        valueListenable: _textSearcher,
                        builder: (context, searcher, child) => searcher != null
                            ? TextSearchView(textSearcher: searcher)
                            : const SizedBox(),
                      ),
                      // Outline/TOC View
                      ValueListenableBuilder(
                        valueListenable: _outline,
                        builder: (context, outlineData, child) => OutlineView(
                          outline: outlineData,
                          controller: _controller,
                        ),
                      ),
                      // Thumbnails View
                      ValueListenableBuilder(
                        valueListenable: _documentRef,
                        builder: (context, docRef, child) => ThumbnailsView(
                          documentRef: docRef,
                          controller: _controller,
                        ),
                      ),
                      // Markers View
                      MarkersView(
                        markers: _markers.values.expand((e) => e).toList(),
                        onTap: (marker) {
                          final rect = _controller.calcRectForRectInsidePage(
                            pageNumber: marker.ranges.pageNumber,
                            rect: marker.ranges.bounds,
                          );
                          _controller.ensureVisible(rect);
                        },
                        onDeleteTap: (marker) {
                          setState(() {
                            _markers[marker.ranges.pageNumber]?.remove(marker);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the main PDF viewer area.
  Widget _buildPdfViewer() {
    return Expanded(
      child: ValueListenableBuilder(
        valueListenable: _documentRef,
        builder: (context, docRef, child) {
          if (docRef == null) {
            return const Center(
              child: Text(
                'لم يتم تحميل أي مستند',
                style: TextStyle(fontSize: 20),
              ),
            );
          }
          return PdfViewer(
            docRef,
            controller: _controller,
            params: PdfViewerParams(
              enableTextSelection: true,
              maxScale: 8.0,
              // Callbacks for document events
              onDocumentChanged: _onDocumentChanged,
              onViewerReady: _onViewerReady,
              onTextSelectionChange: (selections) =>
                  _textSelections = selections,
              // Custom paint callbacks to draw markers and search results
              pagePaintCallbacks: [
                if (_textSearcher.value != null)
                  _textSearcher.value!.pageTextMatchPaintCallback,
                _paintMarkers,
              ],
              // Loading indicator
              loadingBannerBuilder: (context, bytesDownloaded, totalBytes) =>
                  Center(
                child: CircularProgressIndicator(
                  value:
                      totalBytes != null ? bytesDownloaded / totalBytes : null,
                  backgroundColor: Colors.grey,
                ),
              ),
              // Link handling
              linkHandlerParams: PdfLinkHandlerParams(
                onLinkTap: (link) {
                  if (link.url != null) {
                    _showUrlNavigateDialog(link.url!);
                  } else if (link.dest != null) {
                    _controller.goToDest(link.dest!);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Helper Widgets ---

  /// Generic IconButton factory.
  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required bool isEnabled,
    required VoidCallback onPressed,
    VisualDensity? visualDensity,
  }) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      visualDensity: visualDensity,
      onPressed: isEnabled && _controller.isReady ? onPressed : null,
    );
  }

  /// Specific button for creating markers.
  Widget _buildMarkerButton({
    required Color color,
    required String tooltip,
    required bool isEnabled,
    VisualDensity? visualDensity,
  }) {
    return IconButton(
      icon: Icon(Icons.circle, color: color),
      tooltip: tooltip,
      visualDensity: visualDensity,
      onPressed: isEnabled ? () => _addCurrentSelectionToMarkers(color) : null,
    );
  }

  // --- Logic and Handlers ---

  /// Opens the PDF document from a local file or a remote URL.
  Future<void> _openDocument() async {
    // This logic is specific to your app's file handling.
    final fileExists =
        await isFileDownloaded(title: widget.title, directory: 'books');
    if (fileExists) {
      final appDir = await getApplicationSupportDirectory();
      final filePath =
          '${appDir.path}${Platform.pathSeparator}books${Platform.pathSeparator}${widget.title}.pdf';
      _documentRef.value = PdfDocumentRefFile(filePath);
    } else {
      // Assumes `booksTitles` is a map of titles to URLs.
      final url = booksTitles[widget.title];
      if (url != null) {
        _documentRef.value = PdfDocumentRefUri(Uri.parse(url));
      }
    }
  }

  /// Callback when a new document is loaded.
  void _onDocumentChanged(PdfDocument? document) {
    if (document == null) {
      _textSearcher.value?.dispose();
      _textSearcher.value = null;
      _outline.value = null;
      _textSelections = null;
      _markers.clear();
    }
  }

  /// Callback when the viewer is ready.
  Future<void> _onViewerReady(
      PdfDocument document, PdfViewerController controller) async {
    _outline.value = await document.loadOutline();
    _textSearcher.value = PdfTextSearcher(controller)
      ..addListener(() => setState(() {}));
  }

  /// Custom painter to draw colored rectangles over marked text.
  void _paintMarkers(Canvas canvas, Rect pageRect, PdfPage page) {
    final markersOnPage = _markers[page.pageNumber];
    if (markersOnPage == null || markersOnPage.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (final marker in markersOnPage) {
      paint.color = marker.color.withAlpha(100);
      for (final range in marker.ranges.ranges) {
        final fragment = PdfTextRangeWithFragments.fromTextRange(
          marker.ranges.pageText,
          range.start,
          range.end,
        );
        if (fragment != null) {
          canvas.drawRect(
            fragment.bounds.toRectInPageRect(page: page, pageRect: pageRect),
            paint,
          );
        }
      }
    }
  }

  /// Adds the currently selected text to the list of markers.
  void _addCurrentSelectionToMarkers(Color color) {
    if (_controller.isReady && _textSelections != null) {
      for (final selection in _textSelections!) {
        setState(() {
          _markers
              .putIfAbsent(selection.pageNumber, () => [])
              .add(Marker(color, selection));
        });
      }
      _textSelections = null; // Clear selection after marking
    }
  }

  /// Shows a confirmation dialog before navigating to an external URL.
  Future<void> _showUrlNavigateDialog(Uri url) async {
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
          textDirection: TextDirection.ltr, // Keep URL LTR
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
      // Use launchUrl with mode to open in an external browser.
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Extracts the filename from a full path or URL.
  static String? _fileName(String? path) {
    if (path == null) return null;
    try {
      return path.split(RegExp(r'[/\\]')).last;
    } catch (e) {
      return path;
    }
  }
}
