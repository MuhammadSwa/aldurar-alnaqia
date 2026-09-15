// NOTE: same viewer API as pdfx_lite (PdfDocument / PdfControllerPinch /
// PdfViewPinch). Switch this import to `package:pdfx_lite/pdfx_lite.dart`
// once the project upgrades to Flutter >=3.47.
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Shared pinch-to-zoom PDF viewer with standard loading/error states.
///
/// Replaces the triplicated `PdfViewPinchBuilders(DefaultBuilderOptions())`
/// blocks in `HeliaNasabContent`, `TareeqaSanadContent` and
/// `BookViewerScreen`.
class AppPdfView extends StatelessWidget {
  const AppPdfView({
    super.key,
    required this.controller,
    this.padding = 0,
    this.onPageChanged,
    this.onDocumentLoaded,
    this.onDocumentError,
    this.documentLoaderBuilder,
    this.errorBuilder,
  });

  final PdfControllerPinch controller;
  final double padding;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<PdfDocument>? onDocumentLoaded;
  final ValueChanged<Object>? onDocumentError;
  final Widget Function()? documentLoaderBuilder;
  final Widget Function(Object error)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return PdfViewPinch(
      controller: controller,
      scrollDirection: Axis.vertical,
      padding: padding,
      onPageChanged: onPageChanged,
      onDocumentLoaded: onDocumentLoaded,
      onDocumentError: onDocumentError,
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) =>
            documentLoaderBuilder?.call() ??
            const Center(child: CircularProgressIndicator()),
        pageLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, error) =>
            errorBuilder?.call(error) ??
            Center(child: Text('تعذّر فتح الملف: $error')),
      ),
    );
  }
}
