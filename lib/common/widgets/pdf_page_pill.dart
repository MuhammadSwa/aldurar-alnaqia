import 'package:material_ui/material_ui.dart';
import 'package:pdfx/pdfx.dart';

/// Small page indicator shown in a reader AppBar; tap to jump to a page.
///
/// Shared by the book viewer (and available to manuscript readers). The host
/// owns the jump UI and passes it as [onTap].
class PdfPagePill extends StatelessWidget {
  const PdfPagePill({
    required this.controller,
    required this.onTap,
    super.key,
  });

  final PdfControllerPinch controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PdfPageNumber(
      controller: controller,
      builder: (_, loadingState, page, pagesCount) {
        if (loadingState != PdfLoadingState.success) {
          return const SizedBox.shrink();
        }
        return ActionChip(
          label: Text('$page / ${pagesCount ?? '…'}'),
          avatar: const Icon(Icons.book_outlined, size: 18),
          tooltip: 'الانتقال إلى صفحة',
          onPressed: onTap,
        );
      },
    );
  }
}
