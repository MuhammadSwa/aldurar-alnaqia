import 'dart:async';

import 'package:aldurar_alnaqia/screens/library_screen/pdf_viewer_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdfrx/pdfrx.dart';

// Your other imports
import 'package:aldurar_alnaqia/screens/library_screen/pdfViewer/markers_view.dart';
import 'package:aldurar_alnaqia/screens/library_screen/pdfViewer/outline_view.dart';
import 'package:aldurar_alnaqia/screens/library_screen/pdfViewer/search_view.dart';
import 'package:aldurar_alnaqia/screens/library_screen/pdfViewer/thumbnails_view.dart';

// Import the new controller

class PdfviewerWidget extends StatefulWidget {
  const PdfviewerWidget({super.key, required this.title});
  final String title;

  @override
  State<PdfviewerWidget> createState() => _PdfviewerWidgetState();
}

class _PdfviewerWidgetState extends State<PdfviewerWidget>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final PdfViewerGetxController controller;

  late final TabController _tabController;
  final FocusNode _searchFocusNode = FocusNode();
  StreamSubscription? _sidebarVisibilitySubscription;

  bool get _isMobileDevice => MediaQuery.of(context).size.shortestSide < 600;

  @override
  void initState() {
    super.initState();
    controller = Get.put(PdfViewerGetxController(title: widget.title),
        tag: widget.title);
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_updateSearchFocus);
    _sidebarVisibilitySubscription =
        controller.showSidePane.listen((_) => _updateSearchFocus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _sidebarVisibilitySubscription?.cancel();
    _tabController.removeListener(_updateSearchFocus);
    _tabController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }

  void _updateSearchFocus() {
    // Determine if the search input should have focus
    final shouldBeFocused =
        controller.showSidePane.value && _tabController.index == 0;

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
        onPressed: () => controller.showSidePane.toggle(),
      ),
      title: Obx(() => Text(
            _fileName(controller.documentRef.value?.sourceName) ?? 'عارض الكتب',
            overflow: TextOverflow.ellipsis,
          )),
      actions: [_buildAppBarActions()],
    );
  }

  Widget _buildAppBarActions() {
    final visualDensity = _isMobileDevice ? VisualDensity.compact : null;

    // Obx rebuilds the row when isViewerReady or documentRef changes
    return Obx(() {
      final isActionable = controller.documentRef.value != null &&
          controller.isViewerReady.value;
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
            onPressed: () => controller.pdfController.goToPage(pageNumber: 1),
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
    });
  }

  Widget _buildSidePane() {
    // Use Obx to rebuild the side pane when its visibility changes
    return Obx(() => AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: SizedBox(
            width: controller.showSidePane.value && !_isMobileDevice
                ? 320.0
                : (controller.showSidePane.value && _isMobileDevice
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
        ));
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        // Search View
        Obx(() => controller.textSearcher.value != null
            ? TextSearchView(
                focusNode: _searchFocusNode,
                textSearcher: controller.textSearcher.value!)
            : const SizedBox()),
        // Outline/TOC View
        Obx(() => OutlineView(
              outline: controller.outline.value,
              controller: controller.pdfController,
            )),
        // Thumbnails View
        Obx(() => ThumbnailsView(
              documentRef: controller.documentRef.value,
              controller: controller.pdfController,
            )),
        // Markers View
        Obx(() => MarkersView(
              markers: controller.markers.values.expand((e) => e).toList(),
              onTap: (marker) {
                final rect = controller.pdfController.calcRectForRectInsidePage(
                  pageNumber: marker.ranges.pageNumber,
                  rect: marker.ranges.bounds,
                );
                controller.pdfController.ensureVisible(rect);
              },
              onDeleteTap: (marker) {
                controller.markers[marker.ranges.pageNumber]?.remove(marker);
                controller.markers.refresh();
              },
            )),
      ],
    );
  }

  Widget _buildPdfViewer() {
    return Expanded(
      child: Obx(() {
        final docRef = controller.documentRef.value;
        if (docRef == null) {
          return const Center(
              child: Text('لم يتم تحميل أي مستند',
                  style: TextStyle(fontSize: 20)));
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
              if (controller.textSearcher.value != null)
                controller.textSearcher.value!.pageTextMatchPaintCallback,
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
                  controller.showUrlNavigateDialog(link.url!);
                } else if (link.dest != null) {
                  controller.pdfController.goToDest(link.dest!);
                }
              },
            ),
          ),
        );
      }),
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
