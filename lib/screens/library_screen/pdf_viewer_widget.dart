import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
// import 'package:file_selector/file_selector.dart' as fs;
import 'package:path_provider/path_provider.dart';
// import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yosria/common/helpers/helpers.dart';
import 'package:yosria/screens/library_screen/library_screen.dart';
// import 'package:yosria/common/helpers/helpers.dart';
// import 'package:yosria/screens/library_screen/library_screen.dart';
import 'package:yosria/screens/library_screen/pdfViewer/markers_view.dart';
import 'package:yosria/screens/library_screen/pdfViewer/outline_view.dart';
import 'package:yosria/screens/library_screen/pdfViewer/search_view.dart';
import 'package:yosria/screens/library_screen/pdfViewer/thumbnails_view.dart';
// import 'package:yosria/screens/library_screen/pdfViewer/password_dialog.dart';

// import 'package:url_launcher/url_launcher.dart';

class PdfviewerWidget extends StatefulWidget {
  const PdfviewerWidget({super.key, required this.title});
  final String title;

  @override
  State<PdfviewerWidget> createState() => _PdfviewerWidgetState();
}

class _PdfviewerWidgetState extends State<PdfviewerWidget>
    with WidgetsBindingObserver {
  final documentRef = ValueNotifier<PdfDocumentRef?>(null);
  final controller = PdfViewerController();
  final showLeftPane = ValueNotifier<bool>(false);
  final outline = ValueNotifier<List<PdfOutlineNode>?>(null);
  final textSearcher = ValueNotifier<PdfTextSearcher?>(null);
  final _markers = <int, List<Marker>>{};
  List<PdfTextRanges>? textSelections;

  void _update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    openDefaultAsset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    textSearcher.value?.dispose();
    textSearcher.dispose();
    showLeftPane.dispose();
    outline.dispose();
    documentRef.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted) setState(() {});
  }

  static bool determineWhetherMobileDeviceOrNot() {
    final data = MediaQueryData.fromView(
        WidgetsBinding.instance.platformDispatcher.views.single);
    return data.size.shortestSide < 600;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            showLeftPane.value = !showLeftPane.value;
          },
        ),
        title: ValueListenableBuilder(
          valueListenable: documentRef,
          builder: (context, documentRef, child) {
            final isMobileDevice = determineWhetherMobileDeviceOrNot();
            final visualDensity = isMobileDevice ? VisualDensity.compact : null;
            return Row(
              children: [
                if (!isMobileDevice) ...[
                  Expanded(
                    child:
                        Text(_fileName(widget.title) ?? 'No document loaded'),
                  ),
                  const SizedBox(width: 10),
                  // FilledButton(
                  //     onPressed: () => openFile(), child: Text('Open File')),
                  // const SizedBox(width: 20),
                  // FilledButton(
                  //     onPressed: () => openUri(), child: Text('Open URL')),
                  // const Spacer(),
                ],
                IconButton(
                  visualDensity: visualDensity,
                  icon: const Icon(
                    Icons.circle,
                    color: Colors.red,
                  ),
                  onPressed: documentRef == null
                      ? null
                      : () => _addCurrentSelectionToMarkers(Colors.red),
                ),
                IconButton(
                  visualDensity: visualDensity,
                  icon: const Icon(
                    Icons.circle,
                    color: Colors.green,
                  ),
                  onPressed: documentRef == null
                      ? null
                      : () => _addCurrentSelectionToMarkers(Colors.green),
                ),
                IconButton(
                  visualDensity: visualDensity,
                  icon: const Icon(
                    Icons.circle,
                    color: Colors.orangeAccent,
                  ),
                  onPressed: documentRef == null
                      ? null
                      : () =>
                          _addCurrentSelectionToMarkers(Colors.orangeAccent),
                ),
                IconButton(
                  visualDensity: visualDensity,
                  icon: const Icon(Icons.zoom_in),
                  onPressed: documentRef == null
                      ? null
                      : () {
                          if (controller.isReady) controller.zoomUp();
                        },
                ),
                IconButton(
                  visualDensity: visualDensity,
                  icon: const Icon(Icons.zoom_out),
                  onPressed: documentRef == null
                      ? null
                      : () {
                          if (controller.isReady) controller.zoomDown();
                        },
                ),
                IconButton(
                  visualDensity: visualDensity,
                  icon: const Icon(Icons.first_page),
                  onPressed: documentRef == null
                      ? null
                      : () {
                          if (controller.isReady) {
                            controller.goToPage(pageNumber: 1);
                          }
                        },
                ),
                IconButton(
                  visualDensity: visualDensity,
                  icon: const Icon(Icons.last_page),
                  onPressed: documentRef == null
                      ? null
                      : () {
                          if (controller.isReady) {
                            controller.goToPage(
                                pageNumber: controller.pageCount);
                          }
                        },
                ),
              ],
            );
          },
        ),
      ),
      body: Row(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: ValueListenableBuilder(
              valueListenable: showLeftPane,
              builder: (context, isLeftPaneShown, child) {
                final isMobileDevice = determineWhetherMobileDeviceOrNot();
                return SizedBox(
                  width: isLeftPaneShown ? 300 : 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(1, 0, 4, 0),
                    child: DefaultTabController(
                      length: 4,
                      child: Column(
                        children: [
                          if (isMobileDevice)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                children: [
                                  ValueListenableBuilder(
                                    valueListenable: documentRef,
                                    builder: (context, documentRef, child) =>
                                        Expanded(
                                      child: Text(
                                        _fileName(documentRef?.sourceName) ??
                                            'No document loaded',
                                        softWrap: false,
                                      ),
                                    ),
                                  ),
                                  // IconButton(
                                  //   icon: const Icon(Icons.file_open),
                                  //   onPressed: () {
                                  //     showLeftPane.value = false;
                                  //     openFile();
                                  //   },
                                  // ),
                                  // IconButton(
                                  //   icon: const Icon(Icons.http),
                                  //   onPressed: () {
                                  //     showLeftPane.value = false;
                                  //     openUri();
                                  //   },
                                  // ),
                                ],
                              ),
                            ),
                          const ClipRect(
                            // NOTE: without ClipRect, TabBar shown even if the width is 0
                            child: TabBar(tabs: [
                              Tab(icon: Icon(Icons.search), text: 'Search'),
                              Tab(icon: Icon(Icons.menu_book), text: 'TOC'),
                              Tab(icon: Icon(Icons.image), text: 'Pages'),
                              Tab(icon: Icon(Icons.bookmark), text: 'Markers'),
                            ]),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                ValueListenableBuilder(
                                  valueListenable: textSearcher,
                                  builder: (context, textSearcher, child) {
                                    if (textSearcher == null)
                                      return const SizedBox();
                                    return TextSearchView(
                                        textSearcher: textSearcher);
                                  },
                                ),
                                ValueListenableBuilder(
                                  valueListenable: outline,
                                  builder: (context, outline, child) =>
                                      OutlineView(
                                    outline: outline,
                                    controller: controller,
                                  ),
                                ),
                                ValueListenableBuilder(
                                  valueListenable: documentRef,
                                  builder: (context, documentRef, child) =>
                                      ThumbnailsView(
                                    documentRef: documentRef,
                                    controller: controller,
                                  ),
                                ),
                                MarkersView(
                                  markers:
                                      _markers.values.expand((e) => e).toList(),
                                  onTap: (marker) {
                                    final rect =
                                        controller.calcRectForRectInsidePage(
                                      pageNumber:
                                          marker.ranges.pageText.pageNumber,
                                      rect: marker.ranges.bounds,
                                    );
                                    controller.ensureVisible(rect);
                                  },
                                  onDeleteTap: (marker) {
                                    _markers[marker.ranges.pageNumber]!
                                        .remove(marker);
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ValueListenableBuilder(
                    valueListenable: documentRef,
                    builder: (context, docRef, child) {
                      if (docRef == null) {
                        return const Center(
                          child: Text(
                            'No document loaded',
                            style: TextStyle(fontSize: 20),
                          ),
                        );
                      }
                      return PdfViewer(
                        docRef,
                        // PdfViewer.asset(
                        //   'assets/hello.pdf',
                        // PdfViewer.file(
                        //   r"D:\pdfrx\example\assets\hello.pdf",
                        // PdfViewer.uri(
                        //   Uri.parse(
                        //       'https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/PDF32000_2008.pdf'),
                        // Set password provider to show password dialog
                        //passwordProvider: () => passwordDialog(context),
                        controller: controller,
                        params: PdfViewerParams(
                          enableTextSelection: true,
                          maxScale: 8,
                          // facing pages algorithm
                          // layoutPages: (pages, params) {
                          //   // They should be moved outside function
                          //   const isRightToLeftReadingOrder = false;
                          //   const needCoverPage = true;
                          //   final width = pages.fold(
                          //       0.0, (prev, page) => max(prev, page.width));

                          //   final pageLayouts = <Rect>[];
                          //   double y = params.margin;
                          //   for (int i = 0; i < pages.length; i++) {
                          //     const offset = needCoverPage ? 1 : 0;
                          //     final page = pages[i];
                          //     final pos = i + offset;
                          //     final isLeft = isRightToLeftReadingOrder
                          //         ? (pos & 1) == 1
                          //         : (pos & 1) == 0;

                          //     final otherSide = (pos ^ 1) - offset;
                          //     final h = 0 <= otherSide && otherSide < pages.length
                          //         ? max(page.height, pages[otherSide].height)
                          //         : page.height;

                          //     pageLayouts.add(
                          //       Rect.fromLTWH(
                          //         isLeft
                          //             ? width + params.margin - page.width
                          //             : params.margin * 2 + width,
                          //         y + (h - page.height) / 2,
                          //         page.width,
                          //         page.height,
                          //       ),
                          //     );
                          //     if (pos & 1 == 1 || i + 1 == pages.length) {
                          //       y += h + params.margin;
                          //     }
                          //   }
                          //   return PdfPageLayout(
                          //     pageLayouts: pageLayouts,
                          //     documentSize: Size(
                          //       (params.margin + width) * 2 + params.margin,
                          //       y,
                          //     ),
                          //   );
                          // },
                          //
                          onViewSizeChanged:
                              (viewSize, oldViewSize, controller) {
                            if (oldViewSize != null) {
                              //
                              // Calculate the matrix to keep the center position during device
                              // screen rotation
                              //
                              // The most important thing here is that the transformation matrix
                              // is not changed on the view change.
                              final centerPosition =
                                  controller.value.calcPosition(oldViewSize);
                              final newMatrix =
                                  controller.calcMatrixFor(centerPosition);
                              // Don't change the matrix in sync; the callback might be called
                              // during widget-tree's build process.
                              Future.delayed(
                                const Duration(milliseconds: 200),
                                () => controller.goTo(newMatrix),
                              );
                            }
                          },
                          viewerOverlayBuilder:
                              (context, size, handleLinkTap) => [
                            //
                            // Example use of GestureDetector to handle custom gestures
                            //
                            // GestureDetector(
                            //   behavior: HitTestBehavior.translucent,
                            //   // If you use GestureDetector on viewerOverlayBuilder, it breaks link-tap handling
                            //   // and you should manually handle it using onTapUp callback
                            //   onTapUp: (details) {
                            //     handleLinkTap(details.localPosition);
                            //   },
                            //   onDoubleTap: () {
                            //     controller.zoomUp(loop: true);
                            //   },
                            //   // Make the GestureDetector covers all the viewer widget's area
                            //   // but also make the event go through to the viewer.
                            //   child: IgnorePointer(
                            //     child:
                            //         SizedBox(width: size.width, height: size.height),
                            //   ),
                            // ),
                            //
                            // Scroll-thumbs example
                            //
                            // Show vertical scroll thumb on the right; it has page number on it
                            PdfViewerScrollThumb(
                              controller: controller,
                              orientation: ScrollbarOrientation.right,
                              thumbSize: const Size(40, 25),
                              thumbBuilder: (context, thumbSize, pageNumber,
                                      controller) =>
                                  Container(
                                color: Colors.black,
                                child: Center(
                                  child: Text(
                                    pageNumber.toString(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            // Just a simple horizontal scroll thumb on the bottom
                            PdfViewerScrollThumb(
                              controller: controller,
                              orientation: ScrollbarOrientation.bottom,
                              thumbSize: const Size(80, 30),
                              thumbBuilder: (context, thumbSize, pageNumber,
                                      controller) =>
                                  Container(
                                color: Colors.red,
                              ),
                            ),
                          ],
                          //
                          // Loading progress indicator example
                          //
                          loadingBannerBuilder:
                              (context, bytesDownloaded, totalBytes) => Center(
                            child: CircularProgressIndicator(
                              value: totalBytes != null
                                  ? bytesDownloaded / totalBytes
                                  : null,
                              backgroundColor: Colors.grey,
                            ),
                          ),
                          //
                          // Link handling example
                          //
                          linkHandlerParams: PdfLinkHandlerParams(
                            onLinkTap: (link) {
                              if (link.url != null) {
                                navigateToUrl(link.url!);
                              } else if (link.dest != null) {
                                controller.goToDest(link.dest);
                              }
                            },
                          ),
                          pagePaintCallbacks: [
                            if (textSearcher.value != null)
                              textSearcher.value!.pageTextMatchPaintCallback,
                            _paintMarkers,
                          ],
                          onDocumentChanged: (document) async {
                            if (document == null) {
                              textSearcher.value?.dispose();
                              textSearcher.value = null;
                              outline.value = null;
                              textSelections = null;
                              _markers.clear();
                            }
                          },
                          onViewerReady: (document, controller) async {
                            outline.value = await document.loadOutline();
                            textSearcher.value = PdfTextSearcher(controller)
                              ..addListener(_update);
                          },
                          onTextSelectionChange: (selections) {
                            textSelections = selections;
                          },
                        ),
                      );
                    }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _paintMarkers(Canvas canvas, Rect pageRect, PdfPage page) {
    final markers = _markers[page.pageNumber];
    if (markers == null) {
      return;
    }
    for (final marker in markers) {
      final paint = Paint()
        ..color = marker.color.withAlpha(100)
        ..style = PaintingStyle.fill;

      for (final range in marker.ranges.ranges) {
        final f = PdfTextRangeWithFragments.fromTextRange(
          marker.ranges.pageText,
          range.start,
          range.end,
        );
        if (f != null) {
          canvas.drawRect(
            f.bounds.toRectInPageRect(page: page, pageRect: pageRect),
            paint,
          );
        }
      }
    }
  }

  void _addCurrentSelectionToMarkers(Color color) {
    if (controller.isReady && textSelections != null) {
      for (final selectedText in textSelections!) {
        _markers
            .putIfAbsent(selectedText.pageNumber, () => [])
            .add(Marker(color, selectedText));
      }
      setState(() {});
    }
  }

  Future<void> navigateToUrl(Uri url) async {
    if (await shouldOpenUrl(context, url)) {
      await launchUrl(url);
    }
  }

  Future<bool> shouldOpenUrl(BuildContext context, Uri url) async {
    final result = await showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Navigate to URL?'),
          content: SelectionArea(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                      text:
                          'Do you want to navigate to the following location?\n'),
                  TextSpan(
                    text: url.toString(),
                    style: const TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> openDefaultAsset() async {
    // documentRef.value = PdfDocumentRefUri(Uri.parse(booksTitles[widget.title]!));
    final fileRef =
        await isFileDownloaded(title: widget.title, directory: 'books');
    if (!fileRef) {
      // documentRef.value = PdfDocumentRefFile(fileRef);
      documentRef.value =
          PdfDocumentRefUri(Uri.parse(booksTitles[widget.title]!));
      return;
    }
    final snapshotDir = await getApplicationSupportDirectory();
    documentRef.value = PdfDocumentRefFile(
      '${snapshotDir.path}/books/${widget.title}.pdf',
    );

//                   PdfDocumentRefUri(Uri.parse(booksTitles[widget.title]!));
//               final fileRef = PdfDocumentRefFile(
//                   '${snapshotDir.data?.path}/books/${widget.title}.pdf');
  }

  // Future<void> openFile() async {
  //   final file = await fs.openFile(acceptedTypeGroups: [
  //     const fs.XTypeGroup(
  //       label: 'PDF files',
  //       extensions: <String>['pdf'],
  //       uniformTypeIdentifiers: ['com.adobe.pdf'],
  //     )
  //   ]);
  //   if (file == null) return;
  //   if (kIsWeb) {
  //     final bytes = await file.readAsBytes();
  //     documentRef.value = PdfDocumentRefData(
  //       bytes,
  //       sourceName: file.name,
  //       passwordProvider: () => passwordDialog(context),
  //     );
  //   } else {
  //     documentRef.value = PdfDocumentRefFile(file.path,
  //         passwordProvider: () => passwordDialog(context));
  //   }
  // }

  // Future<void> openUri() async {
  //   final result = await showDialog<String?>(
  //     context: context,
  //     builder: (context) {
  //       final controller = TextEditingController();
  //       controller.text =
  //           'https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/PDF32000_2008.pdf';
  //       return AlertDialog(
  //         title: const Text('Open URL'),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             if (kIsWeb)
  //               const Text(
  //                 'Note: The URL must be CORS-enabled.',
  //                 style: TextStyle(color: Colors.red),
  //               ),
  //             TextField(
  //               controller: controller,
  //               decoration: const InputDecoration(hintText: 'URL'),
  //             ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(),
  //             child: const Text('Cancel'),
  //           ),
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(controller.text),
  //             child: const Text('Open'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  //   if (result == null) return;
  //   final uri = Uri.parse(result);
  //   documentRef.value = PdfDocumentRefUri(
  //     uri,
  //     passwordProvider: () => passwordDialog(context),
  //   );
  // }

  static String? _fileName(String? path) {
    if (path == null) return null;
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }
}

// class _PdfviewerWidgetState extends State<PdfviewerWidget> {
//   final documentRef = ValueNotifier<PdfDocumentRef?>(null);
//   final controller = PdfViewerController();
//   final showLeftPane = ValueNotifier<bool>(false);
//   final outline = ValueNotifier<List<PdfOutlineNode>?>(null);
//   late final textSearcher = PdfTextSearcher(controller)..addListener(_update);
//   final _markers = <int, List<Marker>>{};
//   PdfTextRanges? _selectedText;
//
//   void _update() {
//     if (mounted) {
//       setState(() {});
//     }
//   }
//
//   @override
//   void dispose() {
//     textSearcher.removeListener(_update);
//     textSearcher.dispose();
//     showLeftPane.dispose();
//     outline.dispose();
//     documentRef.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(
//           icon: const Icon(Icons.menu),
//           onPressed: () {
//             showLeftPane.value = !showLeftPane.value;
//           },
//         ),
//         title: Text(widget.title,style: const TextStyle(fontSize: 16),maxLines: 2,),
//         actions: [
//           IconButton(
//             icon: const Icon(
//               Icons.circle,
//               color: Colors.red,
//             ),
//             onPressed: () => _addCurrentSelectionToMarkers(Colors.red),
//           ),
//           IconButton(
//             icon: const Icon(
//               Icons.circle,
//               color: Colors.green,
//             ),
//             onPressed: () => _addCurrentSelectionToMarkers(Colors.green),
//           ),
//           IconButton(
//             icon: const Icon(
//               Icons.circle,
//               color: Colors.orangeAccent,
//             ),
//             onPressed: () => _addCurrentSelectionToMarkers(Colors.orangeAccent),
//           ),
//           IconButton(
//             icon: const Icon(Icons.zoom_in),
//             onPressed: () => controller.zoomUp(),
//           ),
//           IconButton(
//             icon: const Icon(Icons.zoom_out),
//             onPressed: () => controller.zoomDown(),
//           ),
//           IconButton(
//             icon: const Icon(Icons.first_page),
//             onPressed: () => controller.goToPage(pageNumber: 1),
//           ),
//           IconButton(
//             icon: const Icon(Icons.last_page),
//             onPressed: () =>
//                 controller.goToPage(pageNumber: controller.pages.length),
//           ),
//         ],
//       ),
//       body: Row(
//         children: [
//           AnimatedSize(
//             duration: const Duration(milliseconds: 300),
//             child: ValueListenableBuilder(
//               valueListenable: showLeftPane,
//               builder: (context, showLeftPane, child) => SizedBox(
//                 width: showLeftPane ? 300 : 0,
//                 child: child!,
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(1, 0, 4, 0),
//                 child: DefaultTabController(
//                   length: 4,
//                   child: Column(
//                     children: [
//                       const TabBar(tabs: [
//                         Tab(icon: Icon(Icons.search), text: 'Search'),
//                         Tab(icon: Icon(Icons.menu_book), text: 'TOC'),
//                         Tab(icon: Icon(Icons.image), text: 'Pages'),
//                         Tab(icon: Icon(Icons.bookmark), text: 'Markers'),
//                       ]),
//                       Expanded(
//                         child: TabBarView(
//                           children: [
//                             // NOTE: documentRef is not explicitly used but it indicates that
//                             // the document is changed.
//                             ValueListenableBuilder(
//                               valueListenable: documentRef,
//                               builder: (context, documentRef, child) =>
//                                   TextSearchView(
//                                 textSearcher: textSearcher,
//                               ),
//                             ),
//                             ValueListenableBuilder(
//                               valueListenable: outline,
//                               builder: (context, outline, child) => OutlineView(
//                                 outline: outline,
//                                 controller: controller,
//                               ),
//                             ),
//                             ValueListenableBuilder(
//                               valueListenable: documentRef,
//                               builder: (context, documentRef, child) =>
//                                   ThumbnailsView(
//                                 documentRef: documentRef,
//                                 controller: controller,
//                               ),
//                             ),
//                             MarkersView(
//                               markers:
//                                   _markers.values.expand((e) => e).toList(),
//                               onTap: (marker) {
//                                 final rect =
//                                     controller.calcRectForRectInsidePage(
//                                   pageNumber: marker.ranges.pageText.pageNumber,
//                                   rect: marker.ranges.bounds,
//                                 );
//                                 controller.ensureVisible(rect);
//                               },
//                               onDeleteTap: (marker) {
//                                 _markers[marker.ranges.pageNumber]!
//                                     .remove(marker);
//                                 setState(() {});
//                               },
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           FutureBuilder(
//             future: getApplicationSupportDirectory(),
//             builder: (context, snapshotDir) {
//               final streamRef =
//                   PdfDocumentRefUri(Uri.parse(booksTitles[widget.title]!));
//               final fileRef = PdfDocumentRefFile(
//                   '${snapshotDir.data?.path}/books/${widget.title}.pdf');
//               return FutureBuilder(
//                   future:
//                       isFileDownloaded(title: widget.title, directory: 'books'),
//                   builder: (context, snapshot) {
//                     return Expanded(
//                       child: Stack(
//                         children: [
//                           PdfViewer(
//                             // PdfDocumentRefFile(
//                             //     '${snapshotDir.data?.path}/books/${widget.title}.pdf'),
//                             snapshot.data == true ? fileRef : streamRef,
//                             controller: controller,
//                             params: PdfViewerParams(
//                               enableTextSelection: true,
//                               maxScale: 8,
//                               //
//                               // Scroll-thumbs example
//                               //
//                               viewerOverlayBuilder: (context, size) => [
//                                 //
//                                 // Double-tap to zoom
//                                 //
//                                 GestureDetector(
//                                   behavior: HitTestBehavior.translucent,
//                                   onDoubleTap: () {
//                                     controller.zoomUp(loop: true);
//                                   },
//                                   child: IgnorePointer(
//                                     child: SizedBox(
//                                         width: size.width, height: size.height),
//                                   ),
//                                 ),
//                                 //
//                                 // Scroll-thumbs example
//                                 //
//                                 // Show vertical scroll thumb on the right; it has page number on it
//                                 PdfViewerScrollThumb(
//                                   controller: controller,
//                                   orientation: ScrollbarOrientation.right,
//                                   thumbSize: const Size(40, 25),
//                                   thumbBuilder: (context, thumbSize, pageNumber,
//                                           controller) =>
//                                       Container(
//                                     color: Colors.black,
//                                     child: Center(
//                                       child: Text(
//                                         pageNumber.toString(),
//                                         style: const TextStyle(
//                                             color: Colors.white),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 // Just a simple horizontal scroll thumb on the bottom
//                                 PdfViewerScrollThumb(
//                                   controller: controller,
//                                   orientation: ScrollbarOrientation.bottom,
//                                   thumbSize: const Size(80, 30),
//                                   thumbBuilder: (context, thumbSize, pageNumber,
//                                           controller) =>
//                                       Container(
//                                     color: Colors.red,
//                                   ),
//                                 ),
//                               ],
//                               //
//                               // Loading progress indicator example
//                               //
//                               loadingBannerBuilder:
//                                   (context, bytesDownloaded, totalBytes) =>
//                                       Center(
//                                 child: CircularProgressIndicator(
//                                   value: totalBytes != null
//                                       ? bytesDownloaded / totalBytes
//                                       : null,
//                                   backgroundColor: Colors.grey,
//                                 ),
//                               ),
//                               //
//                               // Link handling example
//                               //
//                               // GestureDetector/IgnorePointer propagate panning/zooming gestures to the viewer
//                               linkWidgetBuilder: (context, link, size) =>
//                                   MouseRegion(
//                                 cursor: SystemMouseCursors.click,
//                                 hitTestBehavior: HitTestBehavior.translucent,
//                                 child: GestureDetector(
//                                   behavior: HitTestBehavior.translucent,
//                                   onTap: () async {
//                                     if (link.url != null) {
//                                       navigateToUrl(link.url!);
//                                     } else if (link.dest != null) {
//                                       controller.goToDest(link.dest);
//                                     }
//                                   },
//                                   child: IgnorePointer(
//                                     child: Container(
//                                       color: Colors.blue.withOpacity(0.2),
//                                       width: size.width,
//                                       height: size.height,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                               pagePaintCallbacks: [
//                                 textSearcher.pageTextMatchPaintCallback,
//                                 _paintMarkers,
//                               ],
//                               onDocumentChanged: (document) async {
//                                 if (document == null) {
//                                   documentRef.value = null;
//                                   outline.value = null;
//                                   _selectedText = null;
//                                   _markers.clear();
//                                 }
//                               },
//                               onViewerReady: (document, controller) async {
//                                 documentRef.value = controller.documentRef;
//                                 outline.value = await document.loadOutline();
//                               },
//                               onTextSelectionChange: (selection) {
//                                 _selectedText = selection;
//                               },
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   });
//             },
//           )
//         ],
//       ),
//     );
//   }
//
//   void _paintMarkers(Canvas canvas, Rect pageRect, PdfPage page) {
//     final markers = _markers[page.pageNumber];
//     if (markers == null) {
//       return;
//     }
//     for (final marker in markers) {
//       final paint = Paint()
//         ..color = marker.color.withAlpha(100)
//         ..style = PaintingStyle.fill;
//
//       for (final range in marker.ranges.ranges) {
//         final f = PdfTextRangeWithFragments.fromTextRange(
//           marker.ranges.pageText,
//           range.start,
//           range.end,
//         );
//         if (f != null) {
//           canvas.drawRect(
//             f.bounds.toRectInPageRect(page: page, pageRect: pageRect),
//             paint,
//           );
//         }
//       }
//     }
//   }
//
//   void _addCurrentSelectionToMarkers(Color color) {
//     if (controller.isReady &&
//         _selectedText != null &&
//         _selectedText!.isNotEmpty) {
//       _markers
//           .putIfAbsent(_selectedText!.pageNumber, () => [])
//           .add(Marker(color, _selectedText!));
//       setState(() {});
//     }
//   }
//
//   Future<void> navigateToUrl(Uri url) async {
//     if (await shouldOpenUrl(context, url)) {
//       await launchUrl(url);
//     }
//   }
//
//   Future<bool> shouldOpenUrl(BuildContext context, Uri url) async {
//     final result = await showDialog<bool?>(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('Navigate to URL?'),
//           content: SelectionArea(
//             child: Text.rich(
//               TextSpan(
//                 children: [
//                   const TextSpan(
//                       text:
//                           'Do you want to navigate to the following location?\n'),
//                   TextSpan(
//                     text: url.toString(),
//                     style: const TextStyle(color: Colors.blue),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(false),
//               child: const Text('Cancel'),
//             ),
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(true),
//               child: const Text('Go'),
//             ),
//           ],
//         );
//       },
//     );
//     return result ?? false;
//   }
// }
