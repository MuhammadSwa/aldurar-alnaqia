import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Shared AppBar-chrome state for every reading screen.
///
/// Used by the reader scaffold (zikr text + Hilya/Sanad manuscripts, fed by
/// chrome notifications) and directly by the book viewer. The policy is
/// unified:
///
///  * **Portrait** — a normal screen with a fixed bar. [visible] always
///    reports true; [hide], [toggle] and [readingInteraction] are no-ops
///    and no auto-hide timer runs.
///  * **Landscape** — immersive reading. The bar hides on reading intent,
///    a tap toggles it, and arriving back at the very top reveals it again.
///
/// Hosts differ only in configuration: the book viewer auto-hides 3s after
/// the last show and drives sticky immersive system UI, while the scaffold
/// only adds/removes the AppBar.
///
/// A [ChangeNotifier]: hosts register a `setState` trampoline in
/// `initState`, call [updateOrientation] from `didChangeDependencies` with
/// `MediaQuery.orientationOf(context)`, and dispose it with the state.
class ReaderChromeController extends ChangeNotifier {
  ReaderChromeController({
    this.autoHide,
    this.immersiveSystemUi = false,
    this.canAutoHide,
  });

  /// Delay after the last explicit show before auto-hiding. Null disables
  /// auto-hide (scaffold behavior); the book viewer passes 3 seconds.
  final Duration? autoHide;

  /// Whether hiding also enters sticky immersive system UI and showing
  /// restores edge-to-edge (book viewer). When false, only [visible]
  /// changes and the host swaps the AppBar (scaffold behavior).
  final bool immersiveSystemUi;

  /// Extra guard evaluated when (re)starting the auto-hide timer. The book
  /// viewer passes `() => _controller != null && _error == null` so the
  /// timer never runs over loading/error states.
  final bool Function()? canAutoHide;

  bool _landscape = false;
  bool get landscape => _landscape;

  bool _visible = true;

  /// Portrait always reports true: the bar is fixed there.
  bool get visible => !_landscape || _visible;

  Timer? _timer;
  bool _disposed = false;

  /// Call from the host's `didChangeDependencies`. Restores the fixed bar
  /// (and system UI) when leaving landscape; restarts the auto-hide
  /// countdown when entering it. Rotating back starts visible.
  void updateOrientation(bool landscape) {
    if (_landscape == landscape) return;
    _landscape = landscape;
    if (!_landscape) {
      _timer?.cancel();
      _timer = null;
      _visible = true;
      if (immersiveSystemUi) {
        unawaited(
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
        );
      }
    } else {
      restartHideTimer();
    }
    notifyListeners();
  }

  /// Reveal the bar and (re)start the auto-hide countdown. No-op in
  /// portrait, where the bar is always shown.
  void show() {
    if (_disposed || !_landscape) return;
    if (!_visible) {
      _visible = true;
      if (immersiveSystemUi) {
        unawaited(
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
        );
      }
      notifyListeners();
    }
    restartHideTimer();
  }

  /// Hide the bar immediately. No-op in portrait.
  void hide() {
    if (_disposed || !_landscape) return;
    if (!_visible) return;
    _timer?.cancel();
    _timer = null;
    _visible = false;
    if (immersiveSystemUi) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
    notifyListeners();
  }

  /// Toggle the bar. No-op in portrait.
  void toggle() {
    if (visible) {
      hide();
    } else {
      show();
    }
  }

  /// A drag/pinch or page turn means the user is immersed: hide when
  /// visible, stay hidden otherwise. Ignored in portrait.
  void readingInteraction() {
    if (visible) hide();
  }

  /// (Re)start the auto-hide countdown. Only runs in landscape, with a
  /// configured [autoHide], and while [canAutoHide] allows.
  void restartHideTimer() {
    _timer?.cancel();
    _timer = null;
    final delay = autoHide;
    if (_disposed || !_landscape || delay == null) return;
    if (canAutoHide != null && !canAutoHide!()) return;
    _timer = Timer(delay, () {
      if (_disposed || !_visible) return;
      hide();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    // Always leave immersive mode: other screens expect edge-to-edge.
    if (immersiveSystemUi) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }
}
