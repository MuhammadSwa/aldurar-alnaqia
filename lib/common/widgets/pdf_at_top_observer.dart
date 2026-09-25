import 'dart:async';

import 'package:pdfx/pdfx.dart';

/// Observes a [PdfControllerPinch] and reports arrivals at the very top of
/// a multi-page document.
///
/// Shared by `PdfReaderContent` (manuscript readers, which forward the
/// signal as a reader-chrome notification) and `BookViewerScreen` (which
/// drives its own immersive chrome). Chrome-agnostic on purpose: it only
/// answers "are we at the top?", the host decides what that means.
///
/// Single-page (or not-yet-loaded) documents always report a progress of 0,
/// so they never count as "at top" — otherwise tap-to-hide would be
/// instantly undone.
class PdfAtTopObserver {
  /// Tight threshold for per-tick transform callbacks, which run at 60fps
  /// while scrolling.
  static const double tickThreshold = 0.001;

  /// Looser threshold for settled re-checks after a gesture ends, when the
  /// viewer's progress value may not have landed exactly on 0.
  static const double settleThreshold = 0.01;

  bool _wasAtTop = true;

  /// Whether [controller] currently sits at the very top. Never throws:
  /// a detached or mid-layout viewer simply reports "not at top".
  bool isAtTop(PdfControllerPinch controller) {
    try {
      final total = controller.pagesCount;
      if (total == null || total <= 1) return false;
      return controller.documentProgress <= settleThreshold;
    } catch (_) {
      return false;
    }
  }

  /// Call from a controller listener on every matrix change. Returns true
  /// exactly once per arrival at the top, so the host can reveal its chrome
  /// without reacting to every tick.
  bool handleTransform(PdfControllerPinch controller) {
    final total = controller.pagesCount;
    if (total == null || total <= 1) return false;
    double progress;
    try {
      progress = controller.documentProgress;
    } catch (_) {
      return false;
    }
    final atTop = progress <= tickThreshold;
    if (atTop && !_wasAtTop) {
      _wasAtTop = true;
      return true;
    }
    if (!atTop) _wasAtTop = false;
    return false;
  }

  /// A fling keeps settling after the finger lifts, so re-check once the
  /// viewer's progress value is fresh and invoke [onTop] if it landed at
  /// the top. The host's [onTop] should guard `mounted` itself.
  void handleInteractionEnd(
    PdfControllerPinch controller,
    void Function() onTop,
  ) {
    unawaited(
      Future.microtask(() {
        if (!isAtTop(controller)) return;
        _wasAtTop = true;
        onTop();
      }),
    );
  }

  /// Record an arrival at the top observed through another signal (e.g. a
  /// page jump), so the next transform tick doesn't report it again.
  void markAtTop() => _wasAtTop = true;
}
