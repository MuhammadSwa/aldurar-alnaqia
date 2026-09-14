import 'package:aldurar_alnaqia/screens/zikr_screen/play_audio_btn_zikr_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// NOTE: same viewer API as pdfx_lite (PdfDocument / PdfControllerPinch /
// PdfViewPinch). Switch this import to `package:pdfx_lite/pdfx_lite.dart`
// once the project upgrades to Flutter >=3.47.
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
      child: PdfViewPinch(
        controller: _controller,
        scrollDirection: Axis.vertical,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          pageLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, error) =>
              Center(child: Text('تعذّر فتح الملف: $error')),
        ),
      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.9,
                ),
                child: PdfViewPinch(
                  controller: _controller,
                  scrollDirection: Axis.vertical,
                  builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                    options: const DefaultBuilderOptions(),
                    documentLoaderBuilder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                    pageLoaderBuilder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                    errorBuilder: (_, error) =>
                        Center(child: Text('تعذّر فتح الملف: $error')),
                  ),
                ),
              ),
              ZikrContentWidget(title: title),
            ],
          ),
        );
      },
    );
  }
}
