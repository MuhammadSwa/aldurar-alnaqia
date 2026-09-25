import 'package:aldurar_alnaqia/common/reader/reader_scaffold.dart';
import 'package:aldurar_alnaqia/common/widgets/app_pdf_view.dart';
import 'package:aldurar_alnaqia/common/widgets/pdf_at_top_observer.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfx/pdfx.dart';

/// Bundled manuscript PDFs are named after the zikr's (Arabic) title.
String zikrPdfAsset(Zikr zikr) => 'assets/pdfs/${zikr.title}.pdf';

/// Opens a bundled PDF via Flutter's asset bundle instead of
/// `PdfDocument.openAsset`: pdfx resolves that path with Android's
/// AssetManager directly, which fails on our Arabic filenames
/// (PdfRendererException: file not found). Loading the bytes in Dart and
/// using `openData` writes an ASCII temp file and works reliably.
Future<PdfDocument> openBundledPdf(String assetPath) {
  final bytes = rootBundle.load(assetPath).then(
        (data) =>
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
  return PdfDocument.openData(bytes);
}

/// Lets a pager learn which of its manuscript pages are zoomed in: while one
/// is, horizontal drags must pan it rather than turn the page.
class PdfZoomScope extends InheritedWidget {
  const PdfZoomScope({
    required this.onZoomChanged,
    required super.child,
    super.key,
  });

  /// Called with the reporting [PdfReaderContent] state whenever it becomes
  /// zoomed in or not. Also called from build and dispose, so it must not
  /// rebuild synchronously.
  final void Function(Object manuscript, {required bool zoomed}) onZoomChanged;

  static PdfZoomScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PdfZoomScope>();

  @override
  bool updateShouldNotify(PdfZoomScope oldWidget) => false;
}

/// PDF body shared by Hilya Nasab and the manuscript tab of Tareeqa/Sanad.
///
/// Owns the [PdfControllerPinch] lifecycle (created once in initState,
/// disposed with the state) and reports reading intent to the enclosing
/// [ReaderScaffold]. In portrait the scaffold ignores those intents, so this
/// widget never needs to know the orientation.
///
/// At-top detection lives in [PdfAtTopObserver], shared with the book
/// viewer; only the transport differs (chrome notification here, direct
/// immersive chrome there).
class PdfReaderContent extends StatefulWidget {
  const PdfReaderContent({
    required this.openDocument,
    this.initialPage = 1,
    this.onPageChanged,
    super.key,
  });

  /// Convenience for bundled assets with (possibly Arabic) filenames.
  factory PdfReaderContent.asset(
    String assetPath, {
    Key? key,
    int initialPage = 1,
    ValueChanged<int>? onPageChanged,
  }) =>
      PdfReaderContent(
        key: key,
        openDocument: () => openBundledPdf(assetPath),
        initialPage: initialPage,
        onPageChanged: onPageChanged,
      );

  /// Called exactly once, when the state is created. Point it at a file
  /// (`PdfDocument.openFile`) for non-asset books.
  final Future<PdfDocument> Function() openDocument;

  /// Page to open on; manuscripts start at 1 unless a saved page is passed.
  final int initialPage;

  /// Forwarded to the viewer; used for page persistence by hosts that need
  /// it (the book viewer persists via its own wiring).
  final ValueChanged<int>? onPageChanged;

  @override
  State<PdfReaderContent> createState() => _PdfReaderContentState();
}

class _PdfReaderContentState extends State<PdfReaderContent> {
  late final PdfControllerPinch _controller;
  final PdfAtTopObserver _atTop = PdfAtTopObserver();
  PdfZoomScope? _zoomScope;
  bool _visible = true;
  bool _reportedZoomed = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: widget.openDocument(),
      initialPage: widget.initialPage,
    );
    _controller.addListener(_handleTransform);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _zoomScope = PdfZoomScope.maybeOf(context);
    // False while Tareeqa/Sanad shows its text tab over this manuscript.
    _visible = Visibility.of(context);
    _reportZoom();
  }

  @override
  void dispose() {
    if (_reportedZoomed) _zoomScope?.onZoomChanged(this, zoomed: false);
    _controller.removeListener(_handleTransform);
    _controller.dispose();
    super.dispose();
  }

  /// Zoom 1 is fit-to-width, the viewer's minimum.
  void _reportZoom() {
    final zoomed = _visible && _controller.zoomRatio > 1.01;
    if (zoomed == _reportedZoomed) return;
    _reportedZoomed = zoomed;
    _zoomScope?.onZoomChanged(this, zoomed: zoomed);
  }

  void _sendChrome(ReaderChromeAction action) {
    ReaderChromeNotification(action).dispatch(context);
  }

  /// Reveals the chrome once per arrival at the very top.
  void _handleTransform() {
    _reportZoom();
    if (_atTop.handleTransform(_controller)) {
      _sendChrome(ReaderChromeAction.show);
    }
  }

  /// A fling keeps settling after the finger lifts; re-check once the
  /// viewer's progress value is fresh.
  void _handleInteractionEnd(ScaleEndDetails _) {
    _atTop.handleInteractionEnd(_controller, () {
      if (!mounted) return;
      _sendChrome(ReaderChromeAction.show);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppPdfView(
        controller: _controller,
        onPageChanged: widget.onPageChanged,
        onTap: () => _sendChrome(ReaderChromeAction.toggle),
        onInteractionStart: (_) => _sendChrome(ReaderChromeAction.hide),
        onInteractionEnd: _handleInteractionEnd,
        onScrollbarDrag: () => _sendChrome(ReaderChromeAction.hide),
      ),
    );
  }
}
