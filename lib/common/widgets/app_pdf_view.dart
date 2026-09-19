// NOTE: same viewer API as pdfx_lite (PdfDocument / PdfControllerPinch /
// PdfViewPinch). Switch this import to `package:pdfx_lite/pdfx_lite.dart`
// once the project upgrades to Flutter >=3.47.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:pdfx/pdfx.dart';

/// Shared pinch-to-zoom PDF viewer with standard loading/error states.
///
/// Replaces the triplicated `PdfViewPinchBuilders(DefaultBuilderOptions())`
/// blocks in `HeliaNasabContent`, `TareeqaSanadContent` and
/// `BookViewerScreen`.
///
/// `PdfViewPinch` is driven by an [InteractiveViewer] (via a
/// [TransformationController]), so there is no [ScrollController] to attach
/// a stock [Scrollbar] to. [_PdfScrollbar] is a thin always-visible
/// page-progress bar pinned to the physical right edge: it mirrors
/// `PdfControllerPinch.documentProgress` and drag/tap jumps via
/// `animateToPage`. Pinch-zoom and pan gestures are untouched — only the
/// narrow strip on the right absorbs gestures.
class AppPdfView extends StatelessWidget {
  const AppPdfView({
    required this.controller, super.key,
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
    return Stack(
      children: [
        PdfViewPinch(
          controller: controller,
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
        ),
        _PdfScrollbar(controller: controller),
      ],
    );
  }
}

/// Slim draggable progress bar on the physical right edge.
///
/// Complements the AppBar page-pill jump: the thumb mirrors the actual
/// reading progress (`PdfControllerPinch.documentProgress`) and a vertical
/// drag / tap on the track jumps via `animateToPage`, which in turn updates
/// the AppBar page pill. The thumb is never moved manually and no page
/// bubble is shown. Hidden until the document loads and when there is only
/// one page.
///
/// Smoothness: drag updates jump instantly (`Duration.zero`) and skip
/// repeat targets, so rapid pointer events never restart a 200ms animation.
/// Only taps and the final drag-end settle with a short eased animation.
class _PdfScrollbar extends StatefulWidget {
  const _PdfScrollbar({required this.controller});

  final PdfControllerPinch controller;

  @override
  State<_PdfScrollbar> createState() => _PdfScrollbarState();
}

class _PdfScrollbarState extends State<_PdfScrollbar> {
  /// Last page we already requested; used to drop redundant jumps when a
  /// drag produces many events mapping to the same page.
  int? _lastTarget;

  PdfControllerPinch get _controller => widget.controller;

  @override
  void didUpdateWidget(covariant _PdfScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _lastTarget = null;
  }

  double _progress() {
    final p = _controller.documentProgress;
    if (p.isNaN || p.isInfinite) return 0;
    return p.clamp(0.0, 1.0);
  }

  int _targetPage(double progress, int total) {
    return (1 + progress * (total - 1)).round().clamp(1, total);
  }

  Future<void> _jumpToPage(int page, {required bool smooth}) async {
    try {
      await _controller.animateToPage(
        pageNumber: page,
        duration: smooth
            ? const Duration(milliseconds: 200)
            : Duration.zero,
      );
    } catch (_) {
      // Viewer may be mid-layout or disposed; thumb still follows on next
      // controller tick, so swallowing keeps drags crash-free.
    }
  }

  void _handleDragStart(double dy, double trackHeight, double thumbHeight) {
    // Fresh gesture: forget the previous drag so returning to the same page
    // after panning manually still jumps.
    _lastTarget = null;
    _handleDrag(dy, trackHeight, thumbHeight);
  }

  void _handleDrag(double dy, double trackHeight, double thumbHeight) {
    final usable = trackHeight - thumbHeight;
    final progress = usable <= 0
        ? 0.0
        : ((dy - thumbHeight / 2) / usable).clamp(0.0, 1.0);
    final total = _controller.pagesCount;
    if (total == null || total <= 1) return;
    final target = _targetPage(progress, total);
    if (target == _lastTarget) return;
    _lastTarget = target;
    // Instant jump: no animation to restart, AppBar pill still updates live
    // via the controller's pageListenable.
    unawaited(_jumpToPage(target, smooth: false));
  }

  void _handleTap(double dy, double trackHeight, double thumbHeight) {
    final usable = trackHeight - thumbHeight;
    final progress = usable <= 0
        ? 0.0
        : ((dy - thumbHeight / 2) / usable).clamp(0.0, 1.0);
    final total = _controller.pagesCount;
    if (total == null || total <= 1) return;
    final target = _targetPage(progress, total);
    _lastTarget = target;
    unawaited(_jumpToPage(target, smooth: true));
  }

  void _handleDragEnd() {
    final target = _lastTarget;
    if (target == null) return;
    // Settle exactly on the page-fit matrix after the instant drag jumps.
    unawaited(_jumpToPage(target, smooth: true));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller,
        controller.pageListenable,
        controller.loadingState,
      ]),
      builder: (context, _) {
        if (controller.loadingState.value != PdfLoadingState.success) {
          return const SizedBox.shrink();
        }
        final total = controller.pagesCount;
        if (total == null || total <= 1) return const SizedBox.shrink();

        final progress = _progress();

        return Positioned(
          // Physical right edge regardless of the RTL Directionality.
          right: 2,
          top: 12,
          bottom: 12,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackHeight = constraints.maxHeight;
              final thumbHeight =
                  (trackHeight / total).clamp(32.0, 80.0);
              final thumbTop = progress * (trackHeight - thumbHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _handleTap(
                  details.localPosition.dy,
                  trackHeight,
                  thumbHeight,
                ),
                onVerticalDragStart: (details) => _handleDragStart(
                  details.localPosition.dy,
                  trackHeight,
                  thumbHeight,
                ),
                onVerticalDragUpdate: (details) => _handleDrag(
                  details.localPosition.dy,
                  trackHeight,
                  thumbHeight,
                ),
                onVerticalDragEnd: (_) => _handleDragEnd(),
                onVerticalDragCancel: _handleDragEnd,
                child: Semantics(
                  label: 'شريط تمرير الكتاب',
                  slider: true,
                  child: SizedBox(
                    // Wide hit area, slim visual track.
                    width: 28,
                    height: trackHeight,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Center(
                          child: Container(
                            width: 4,
                            height: trackHeight,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Positioned(
                          top: thumbTop,
                          child: Container(
                            width: 8,
                            height: thumbHeight,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
