import 'package:aldurar_alnaqia/screens/library_screen/pdf_viewer_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

// Your other imports
import 'package:aldurar_alnaqia/screens/library_screen/pdfViewer/markers_view.dart';
import 'package:aldurar_alnaqia/screens/library_screen/pdfViewer/outline_view.dart';
import 'package:aldurar_alnaqia/screens/library_screen/pdfViewer/search_view.dart';
import 'package:aldurar_alnaqia/screens/library_screen/pdfViewer/thumbnails_view.dart';

class PdfviewerWidget extends ConsumerStatefulWidget {
  const PdfviewerWidget({super.key, required this.title});
  final String title;

  @override
  ConsumerState<PdfviewerWidget> createState() => _PdfviewerWidgetState();
}

class _PdfviewerWidgetState extends ConsumerState<PdfviewerWidget>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final BookViewerController controller;
  late final TabController _tabController;
  final FocusNode _searchFocusNode = FocusNode();

  bool get _isMobileDevice => MediaQuery.of(context).size.shortestSide < 600;

  @override
  void initState() {
    super.initState();
    controller = BookViewerController(
      title: widget.title,
      storage: ref.read(storageProvider),
    );

    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_updateSearchFocus);
    controller.addListener(_updateSearchFocus);
    // One-time resume toast when opening on a saved page
    controller.addListener(_maybeShowResumeToast);
  }

  void _maybeShowResumeToast() {
    final page = controller.resumedFromPage;
    if (page != null && mounted) {
      // Clear immediately so the toast shows only once
      controller.resumedFromPage = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('تمت المتابعة من الصفحة $page')));
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _tabController.removeListener(_updateSearchFocus);
    _tabController.dispose();
    _searchFocusNode.dispose();
    controller.removeListener(_updateSearchFocus);
    controller.removeListener(_maybeShowResumeToast);

    // Persist state and clean listeners when widget is disposed.
    // Disposing the controller saves the last page (see controller.dispose).
    controller.detachPageChangeListener();
    controller.dispose();

    super.dispose();
  }

  void _updateSearchFocus() {
    // Determine if the search input should have focus
    final shouldBeFocused =
        controller.showSidePane && _tabController.index == 0;

    if (shouldBeFocused && !_searchFocusNode.hasFocus) {
      // Use a post-frame callback to ensure the widget is built and visible before focusing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    } else if (!shouldBeFocused && _searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      try {
        if (controller.pdfController.isReady) {
          final page = controller.pdfController.pageNumber;
          if (page != null) {
            SharedPreferencesService.setPdfLastPage(widget.title, page);
          }
        }
      } catch (_) {
        // ignore lifecycle save errors during teardown
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        tooltip: 'القائمة',
        icon: const Icon(Icons.menu),
        onPressed: () => controller.toggleSidePane(),
      ),
      title: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Text(
          _fileName(controller.documentRef?.sourceName) ?? 'عارض الكتب',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      actions: [_buildAppBarActions()],
    );
  }

  Widget _buildAppBarActions() {
    final visualDensity = _isMobileDevice ? VisualDensity.compact : null;

    // Rebuilds the row when isViewerReady or documentRef changes
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isActionable =
            controller.documentRef != null && controller.isViewerReady;
        return Row(
          children: [
            _buildMarkerButton(
              color: Colors.red,
              tooltip: 'إضافة علامة حمراء',
              isEnabled: isActionable,
              visualDensity: visualDensity,
            ),
            _buildMarkerButton(
              color: Colors.green,
              tooltip: 'إضافة علامة خضراء',
              isEnabled: isActionable,
              visualDensity: visualDensity,
            ),
            _buildMarkerButton(
              color: Colors.orangeAccent,
              tooltip: 'إضافة علامة برتقالية',
              isEnabled: isActionable,
              visualDensity: visualDensity,
            ),
            const VerticalDivider(width: 20, indent: 10, endIndent: 10),
            _buildIconButton(
              icon: Icons.first_page,
              tooltip: 'الصفحة الأولى',
              isEnabled: isActionable,
              visualDensity: visualDensity,
              onPressed: () =>
                  controller.pdfController.goToPage(pageNumber: 1),
            ),
            _buildIconButton(
              icon: Icons.last_page,
              tooltip: 'الصفحة الأخيرة',
              isEnabled: isActionable,
              visualDensity: visualDensity,
              onPressed: () => controller.pdfController
                  .goToPage(pageNumber: controller.pdfController.pageCount),
            ),
            const SizedBox(width: 8),
          ],
        );
      },
    );
  }

  Widget _buildSidePane() {
    // Rebuild the side pane when its visibility changes
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: SizedBox(
          width: controller.showSidePane && !_isMobileDevice
              ? 320.0
              : (controller.showSidePane && _isMobileDevice
                  ? MediaQuery.sizeOf(context).width * 0.8
                  : 0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 1, 0),
            child: DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  TabBar(controller: _tabController, tabs: const [
                    Tab(icon: Icon(Icons.search), text: 'بحث'),
                    Tab(icon: Icon(Icons.menu_book), text: 'فهرس'),
                    Tab(icon: Icon(Icons.image), text: 'صفحات'),
                    Tab(icon: Icon(Icons.bookmark), text: 'علامات'),
                  ]),
                  Expanded(child: _buildTabBarView()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBarView() {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return TabBarView(
          controller: _tabController,
          children: [
            // Search View
            controller.textSearcher != null
                ? TextSearchView(
                    focusNode: _searchFocusNode,
                    textSearcher: controller.textSearcher!,
                  )
                : const SizedBox(),
            // Outline/TOC View
            OutlineView(
              outline: controller.outline,
              controller: controller.pdfController,
            ),
            // Thumbnails View
            ThumbnailsView(
              documentRef: controller.documentRef,
              controller: controller.pdfController,
            ),
            // Markers View
            MarkersView(
              markers: controller.markers.values.expand((e) => e).toList(),
              onTap: (marker) {
                final rect = controller.pdfController.calcRectForRectInsidePage(
                  pageNumber: marker.ranges.pageNumber,
                  rect: marker.ranges.bounds,
                );
                controller.pdfController.ensureVisible(rect);
              },
              onDeleteTap: controller.removeMarker,
            ),
          ],
        );
      },
    );
  }

  Widget _buildPdfViewer() {
    return Expanded(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final docRef = controller.documentRef;
          if (docRef == null) {
            return const Center(
                child:
                    Text('لم يتم تحميل أي مستند', style: TextStyle(fontSize: 20)));
          }
          return PdfViewer(
            docRef,
            controller: controller.pdfController,
            params: PdfViewerParams(
              enableTextSelection: true,
              maxScale: 8.0,
              onDocumentChanged: controller.onDocumentChanged,
              onViewerReady: controller.onViewerReady,
              onTextSelectionChange: (selections) =>
                  controller.textSelections = selections,
              pagePaintCallbacks: [
                if (controller.textSearcher != null)
                  controller.textSearcher!.pageTextMatchPaintCallback,
                _paintMarkers,
              ],
              loadingBannerBuilder: (context, bytesDownloaded, totalBytes) =>
                  Center(
                child: CircularProgressIndicator(
                  value: totalBytes != null ? bytesDownloaded / totalBytes : null,
                  backgroundColor: Colors.grey,
                ),
              ),
              linkHandlerParams: PdfLinkHandlerParams(
                onLinkTap: (link) {
                  if (link.url != null) {
                    controller.showUrlNavigateDialog(context, link.url!);
                  } else if (link.dest != null) {
                    controller.pdfController.goToDest(link.dest!);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Helper Widgets & Methods ---

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
      onPressed: isEnabled ? onPressed : null,
    );
  }

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
      onPressed: isEnabled
          ? () => controller.addCurrentSelectionToMarkers(color)
          : null,
    );
  }

  void _paintMarkers(Canvas canvas, Rect pageRect, PdfPage page) {
    final markersOnPage = controller.markers[page.pageNumber];
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

  static String? _fileName(String? path) {
    if (path == null) return null;
    try {
      return path.split(RegExp(r'[/\\]')).last;
    } catch (e) {
      return path;
    }
  }
}
