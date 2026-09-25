import 'package:aldurar_alnaqia/common/reader/pdf_reader_content.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/zikr_screen.dart'; // ZikrContentWidget
import 'package:material_ui/material_ui.dart';

/// Canonical sanad zikr (asset filename is the Arabic title).
Zikr get _sanad => zikrById['sanad-tariqa']!;

/// PDF + text body, reusable inside a swipeable [PageView] (no Scaffold).
class TareeqaSanadContent extends StatefulWidget {
  const TareeqaSanadContent({super.key});

  @override
  State<TareeqaSanadContent> createState() => _TareeqaSanadContentState();
}

class _TareeqaSanadContentState extends State<TareeqaSanadContent> {
  bool _pdfRequested = false;
  bool _showPdf = false;

  @override
  Widget build(BuildContext context) {
    // NOTE: PdfViewPinch has its own vertical scrollable; it must NOT be
    // nested under another scrollable. The toggle shows one scrollable at a
    // time. SegmentedButton instead of TabBarView avoids a horizontal-swipe
    // conflict with the outer SlidableZikrScreen PageView.
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
              final wantsPdf = selection.first;
              setState(() {
                _showPdf = wantsPdf;
                // Lazy PDF: before the first tap on «المخطوط» nothing reads
                // or decodes the manuscript — [PdfReaderContent]'s controller
                // is only created when it's first inserted into the tree.
                if (wantsPdf) _pdfRequested = true;
              });
            },
          ),
        ),
        Expanded(
          // After the first load, IndexedStack (not `if/else`) keeps
          // PdfReaderContent mounted when switching to text and back, so the
          // document state survives round-trips.
          child: !_pdfRequested
              ? const ZikrContentWidget(zikrId: 'sanad-tariqa')
              : IndexedStack(
                  index: _showPdf ? 0 : 1,
                  children: [
                    PdfReaderContent.asset(zikrPdfAsset(_sanad)),
                    const ZikrContentWidget(zikrId: 'sanad-tariqa'),
                  ],
                ),
        ),
      ],
    );
}  }
