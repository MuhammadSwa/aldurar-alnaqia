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
/// `PdfControllerPinch.documentProgress` and a drag drives the viewer's
/// matrix continuously (taps glide). Pinch-zoom and pan gestures are
/// untouched — only the narrow strip on the right absorbs gestures.
class AppPdfView extends StatelessWidget {
  const AppPdfView({
    required this.controller, super.key,
    this.padding = 0,
    this.onPageChanged,
    this.onDocumentLoaded,
    this.onDocumentError,
    this.documentLoaderBuilder,
    this.errorBuilder,
    this.onTap,
    this.onInteractionStart,
    this.onInteractionUpdate,
    this.onInteractionEnd,
    this.onScrollbarDrag,
  });

  final PdfControllerPinch controller;
  final double padding;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<PdfDocument>? onDocumentLoaded;
  final ValueChanged<Object>? onDocumentError;
  final Widget Function()? documentLoaderBuilder;
  final Widget Function(Object error)? errorBuilder;

  /// Single-tap on a page (not a drag/pinch, not the scrollbar strip).
  /// Used by readers to toggle immersive chrome (AppBar).
  final VoidCallback? onTap;

  /// Reading-intent signals, passed straight to [PdfViewPinch]: a drag or
  /// pinch starting means the user is reading, so chrome can auto-hide.
  final GestureScaleStartCallback? onInteractionStart;
  final GestureScaleUpdateCallback? onInteractionUpdate;
  final GestureScaleEndCallback? onInteractionEnd;

  /// Fired when the user starts dragging/tapping the scrollbar strip, so a
  /// reader can treat it as reading intent (e.g. hide immersive chrome).
  final VoidCallback? onScrollbarDrag;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          // Only `onTap` here: drag/pinch keep going to the viewer, so
          // scrolling and zooming are untouched. The scrollbar sits above
          // in the stack, so its taps never reach this detector.
          onTap: onTap,
          child: PdfViewPinch(
            controller: controller,
            padding: padding,
            onPageChanged: onPageChanged,
            onDocumentLoaded: onDocumentLoaded,
            onDocumentError: onDocumentError,
            onInteractionStart: onInteractionStart,
            onInteractionUpdate: onInteractionUpdate,
            onInteractionEnd: onInteractionEnd,
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
        ),
        _PdfScrollbar(
          controller: controller,
          onUserScrolled: onScrollbarDrag,
        ),
      ],
    );
  }
}

/// Slim draggable progress bar on the physical right edge.
///
/// Complements the AppBar page-pill jump: the thumb mirrors the actual
/// reading progress (`PdfControllerPinch.documentProgress`). A drag drives
/// the viewer's transformation matrix directly (same mechanism as a finger
/// drag inside the page), so scrolling is continuous and gradual — not
/// page-by-page. A tap glides to the tapped spot with a short animation.
/// Zoom and horizontal pan are preserved; only the vertical offset is
/// driven. Hidden until the document loads and when there is only one page.
class _PdfScrollbar extends StatefulWidget {
  const _PdfScrollbar({required this.controller, this.onUserScrolled});

  final PdfControllerPinch controller;

  /// Called on drag start / tap so the host can treat scrollbar use as
  /// reading intent (e.g. hide immersive chrome).
  final VoidCallback? onUserScrolled;

  @override
  State<_PdfScrollbar> createState() => _PdfScrollbarState();
}

class _PdfScrollbarState extends State<_PdfScrollbar> {
  PdfControllerPinch get _controller => widget.controller;

  double _progress() {
    final p = _controller.documentProgress;
    if (p.isNaN || p.isInfinite) return 0;
    return p.clamp(0.0, 1.0);
  }

  double _progressForDy(double dy, double trackHeight, double thumbHeight) {
    final usable = trackHeight - thumbHeight;
    if (usable <= 0) return 0;
    return ((dy - thumbHeight / 2) / usable).clamp(0.0, 1.0);
  }

  /// Scrolls the document to [progress] (0 = top, 1 = bottom) by
  /// interpolating between the two neighbouring page-fit matrices and
  /// writing the vertical offset straight into the viewer's matrix.
  ///
  /// With [animate] false the matrix is set synchronously, giving 1:1
  /// finger tracking during a drag — exactly like sliding inside the page.
  /// With [animate] true (taps) it glides via `goTo` with a short ease.
  /// Current zoom and horizontal offset are left untouched.
  void _applyProgress(double progress, {required bool animate}) {
    final total = _controller.pagesCount;
    if (total == null || total <= 1) return;
    final p = progress.clamp(0.0, 1.0);
    // Fractional 0-based page index, e.g. 3.4 = 40% from page 4 to page 5.
    final f = p * (total - 1);
    final i0 = f.floor();
    final i1 = f.ceil();
    final t = f - i0;
    try {
      final m0 = _controller.calculatePageFitMatrix(pageNumber: i0 + 1);
      final m1 = _controller.calculatePageFitMatrix(pageNumber: i1 + 1);
      if (m0 == null || m1 == null) return;
      final current = _controller.value;
      // Page-fit matrices share one scale; rescale the interpolated offset
      // so a zoomed-in reader scrolls the full zoomed range, not the fit
      // range.
      final fitScale = m0.row0[0];
      final ratio = fitScale == 0 ? 1.0 : current.row0[0] / fitScale;
      final ty = (m0.row1[3] + (m1.row1[3] - m0.row1[3]) * t) * ratio;
      final target = current.clone()..setEntry(1, 3, ty);
      if (animate) {
        unawaited(
          _controller.goTo(
            destination: target,
            duration: const Duration(milliseconds: 200),
          ),
        );
      } else {
        _controller.value = target;
      }
    } catch (_) {
      // Viewer may be mid-layout or disposed; thumb still follows on next
      // controller tick, so swallowing keeps drags crash-free.
    }
  }

  void _handleDragStart(double dy, double trackHeight, double thumbHeight) {
    widget.onUserScrolled?.call();
    _applyProgress(
      _progressForDy(dy, trackHeight, thumbHeight),
      animate: false,
    );
  }

  void _handleDrag(double dy, double trackHeight, double thumbHeight) {
    _applyProgress(
      _progressForDy(dy, trackHeight, thumbHeight),
      animate: false,
    );
  }

  void _handleTap(double dy, double trackHeight, double thumbHeight) {
    widget.onUserScrolled?.call();
    _applyProgress(
      _progressForDy(dy, trackHeight, thumbHeight),
      animate: true,
    );
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
                // No snap on release: like a finger drag, content stays
                // exactly where the thumb left it.
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
