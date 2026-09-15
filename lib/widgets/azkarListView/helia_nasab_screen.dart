import 'package:aldurar_alnaqia/common/widgets/app_pdf_view.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/play_audio_btn_zikr_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:aldurar_alnaqia/models/consts/alhadra_collection.dart';
import 'package:aldurar_alnaqia/models/consts/orphans.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/zikr_screen.dart';

/// Opens a bundled PDF via Flutter's asset bundle instead of
/// `PdfDocument.openAsset`: pdfx resolves that path with Android's
/// AssetManager directly, which fails on our Arabic filenames
/// (PdfRendererException: file not found). Loading the bytes in Dart and
/// using `openData` writes an ASCII temp file and works reliably.
Future<PdfDocument> _openBundledPdf(String assetPath) {
  final bytes = rootBundle.load(assetPath).then(
        (data) =>
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
  return PdfDocument.openData(bytes);
}

class HeliaNasabScreen extends StatelessWidget {
  const HeliaNasabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final title = alhyliaAndNasab.title;
    return Scaffold(
        appBar: AppBar(
          actions: [
            PlayAudioBtnZikrPage(
              id: title,
              title: title,
              url: alhyliaAndNasab.url,
            ),
          ],
          title: Text(title),
        ),
        body: const HeliaNasabContent());
  }
}

/// PDF-only body, reusable inside a swipeable [PageView] (no [Scaffold])
/// so opening Hilya directly still allows sliding to neighbours.
class HeliaNasabContent extends StatefulWidget {
  const HeliaNasabContent({super.key});

  @override
  State<HeliaNasabContent> createState() => _HeliaNasabContentState();
}

class _HeliaNasabContentState extends State<HeliaNasabContent> {
  late final PdfControllerPinch _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: _openBundledPdf('assets/pdfs/${alhyliaAndNasab.title}.pdf'),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppPdfView(controller: _controller),
    );
  }
}

class TareeqaSanadScreen extends StatelessWidget {
  const TareeqaSanadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final title = sanadAltareeqa.title;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const TareeqaSanadContent(),
    );
  }
}

/// PDF + text body, reusable inside a swipeable [PageView] (no [Scaffold]).
class TareeqaSanadContent extends StatefulWidget {
  const TareeqaSanadContent({super.key});

  @override
  State<TareeqaSanadContent> createState() => _TareeqaSanadContentState();
}

class _TareeqaSanadContentState extends State<TareeqaSanadContent> {
  late final PdfControllerPinch _controller;
  bool _showPdf = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: _openBundledPdf('assets/pdfs/${sanadAltareeqa.title}.pdf'),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = sanadAltareeqa.title;
    // NOTE: PdfViewPinch has its own vertical scrollable. It must NOT be
    // nested inside a SingleChildScrollView (or under another scrollable
    // like ZikrContentWidget's) — the outer scroll steals the gestures so
    // the PDF never scrolls and the whole page moves instead. A toggle
    // shows one scrollable at a time, each with a bounded height, so both
    // scroll independently. A SegmentedButton is used instead of a
    // TabBarView to avoid a horizontal-swipe conflict with the outer
    // SlidableZikrScreen PageView.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.picture_as_pdf_outlined),
                label: Text('المخطوط'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.text_snippet_outlined),
                label: Text('النص'),
              ),
            ],
            selected: {_showPdf},
            onSelectionChanged: (selection) {
              setState(() => _showPdf = selection.first);
            },
          ),
        ),
        Expanded(
          // NOTE: IndexedStack (not `if/else`) keeps PdfViewPinch mounted
          // when switching to text and back. Removing it from the tree
          // detaches its internal state from PdfControllerPinch, so the
          // document would not reload on return.
          child: IndexedStack(
            index: _showPdf ? 0 : 1,
            children: [
              AppPdfView(controller: _controller),
              ZikrContentWidget(title: title),
            ],
          ),
        ),
      ],
    );
  }
}
