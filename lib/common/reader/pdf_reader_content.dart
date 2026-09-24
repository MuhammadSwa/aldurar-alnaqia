import 'package:aldurar_alnaqia/common/reader/reader_scaffold.dart';
import 'package:aldurar_alnaqia/common/widgets/app_pdf_view.dart';
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

/// PDF body shared by Hilya Nasab, the manuscript tab of Tareeqa/Sanad and
/// the book viewer.
///
/// Owns the [PdfControllerPinch] lifecycle (created once in initState,
/// disposed with the state) and reports reading intent to the enclosing
/// [ReaderScaffold]. In portrait the scaffold ignores those intents, so this
/// widget never needs to know the orientation.
class PdfReaderContent extends StatefulWidget {
  const PdfReaderContent({required this.openDocument, super.key});

  /// Convenience for bundled assets with (possibly Arabic) filenames.
  factory PdfReaderContent.asset(String assetPath, {Key? key}) =>
      PdfReaderContent(key: key, openDocument: () => openBundledPdf(assetPath));

  /// Called exactly once, when the state is created. Point it at a file
  /// (`PdfDocument.openFile`) for non-asset books.
  final Future<PdfDocument> Function() openDocument;

  @override
  State<PdfReaderContent> createState() => _PdfReaderContentState();
}

class _PdfReaderContentState extends State<PdfReaderContent> {
  late final PdfControllerPinch _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(document: widget.openDocument());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendChrome(ReaderChromeAction action) {
    ReaderChromeNotification(action).dispatch(context);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppPdfView(
        controller: _controller,
        onTap: () => _sendChrome(ReaderChromeAction.toggle),
        onInteractionStart: (_) => _sendChrome(ReaderChromeAction.hide),
        onScrollbarDrag: () => _sendChrome(ReaderChromeAction.hide),
      ),
    );
  }
}
