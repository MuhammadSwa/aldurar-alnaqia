import 'package:material_ui/material_ui.dart';

// ---------------------------------------------------------------------------
// Swipe back — on iOS and Android, a swipe toward the side screens enter
// from returns to the previous screen: ← in the Arabic (RTL) layout, → in LTR.
//
// The page follows the finger and uncovers the screen beneath; letting go
// past halfway (or flinging) pops it, otherwise it settles back. Screens
// without horizontal gestures of their own take the swipe anywhere
// ([SwipeBackDetector]); the zikr reader's pager takes it on its first page
// ([SwipeBackPageView]).
//
// Relies on the route transition in `RouteTransitions`: the page slides off
// toward that side as the route animation runs 1 → 0, linearly while a pop
// gesture is in progress so it stays under the finger.
//
// [OverscrollHandoffPhysics] is what lets a pager hand drags past its first
// page to something else; the bottom-nav tab pager uses it to slide the side
// menu open from the home tab.
// ---------------------------------------------------------------------------

/// Release speed, in page widths per second, above which the fling's
/// direction decides however far the page was dragged (iOS's value).
const double _kMinFlingVelocity = 1;

/// Follows a horizontal drag that a pager hands over past its first page
/// ([OverscrollHandoffPhysics]).
///
/// Distances are logical pixels, positive = past the first page.
abstract interface class OverscrollTracker {
  /// Whether it is following the current drag.
  bool get isTracking;

  /// Moves by [delta] and returns the part it did not use: all of it when it
  /// can't take the drag, or the overshoot once it is back where it started,
  /// which ends the drag.
  double update(double delta);

  /// Ends the drag; [velocity] is the release speed in pixels per second.
  void end(double velocity);
}

/// Drives a route's pop transition from a horizontal drag through
/// [TransitionRoute]'s public back-gesture hooks.
///
/// Distances are logical pixels, positive = toward the previous screen.
class _SwipeBackTracker implements OverscrollTracker {
  /// The route to pop; owners refresh it from [ModalRoute.of].
  ModalRoute<Object?>? route;

  ModalRoute<Object?>? _tracking;
  NavigatorState? _navigator;
  double _width = 0;

  @override
  bool get isTracking => _tracking != null;

  /// Moves the page by [delta] and returns the part it did not use: all of
  /// it when the page can't be swiped back, or the overshoot once the page
  /// is fully back in place, which ends the swipe.
  @override
  double update(double delta) {
    var tracking = _tracking;
    if (tracking == null) {
      if (delta <= 0) return delta;
      tracking = _start();
      if (tracking == null) return delta;
    }
    final before = tracking.animation!.value;
    final after = (before - delta / _width).clamp(0.0, 1.0);
    tracking.handleUpdateBackGestureProgress(progress: after);
    if (after < 1 || delta >= 0) return 0;
    _tracking = null;
    tracking.handleCancelBackGesture();
    return delta + (after - before) * _width;
  }

  /// Ends the swipe; [velocity] is the release speed in pixels per second.
  @override
  void end(double velocity) {
    final tracking = _tracking;
    if (tracking == null) return;
    _tracking = null;
    final speed = velocity / _width;
    final pop = speed.abs() >= _kMinFlingVelocity
        ? speed > 0
        : tracking.animation!.value < 0.5;
    if (!pop || !tracking.isCurrent) {
      tracking.handleCancelBackGesture();
      return;
    }
    // Not handleCommitBackGesture: it replays the exit from fully shown
    // (made for Android's predictive-back animation), so the page would jump
    // back under the finger before leaving. Finish from where it is instead,
    // keeping the gesture (and so the linear transition) until it's gone.
    final navigator = _navigator!;
    final animation = tracking.animation!;
    navigator.pop();
    if (animation.isAnimating) {
      void onStatus(AnimationStatus _) {
        animation.removeStatusListener(onStatus);
        navigator.didStopUserGesture();
      }

      animation.addStatusListener(onStatus);
    } else {
      navigator.didStopUserGesture();
    }
  }

  /// Releases a swipe cut short by the owner leaving the tree.
  void dispose() {
    if (_tracking == null) return;
    _tracking = null;
    final navigator = _navigator;
    // Disposal runs with the tree locked; the navigator's listeners rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator?.mounted ?? false) navigator!.didStopUserGesture();
    });
  }

  ModalRoute<Object?>? _start() {
    final route = this.route;
    final navigator = route?.navigator;
    if (route == null ||
        navigator == null ||
        !route.isCurrent ||
        !route.popGestureEnabled ||
        navigator.userGestureInProgress) {
      return null;
    }
    final width = route.subtreeContext?.size?.width ?? 0;
    if (width <= 0) return null;
    _width = width;
    _navigator = navigator;
    return _tracking = route..handleStartBackGesture(progress: 1);
  }
}

/// Swipe back (← in RTL) anywhere on [child] to the previous screen.
///
/// For screens with no horizontal gestures of their own: inner horizontal
/// draggables would win the drag first. A pager uses [SwipeBackPageView].
class SwipeBackDetector extends StatefulWidget {
  const SwipeBackDetector({required this.child, super.key});

  final Widget child;

  @override
  State<SwipeBackDetector> createState() => _SwipeBackDetectorState();
}

class _SwipeBackDetectorState extends State<SwipeBackDetector> {
  final _tracker = _SwipeBackTracker();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tracker.route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Toward the side screens enter from: left in RTL, right in LTR.
    final back = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    return GestureDetector(
      onHorizontalDragUpdate: (details) =>
          _tracker.update(details.delta.dx * back),
      onHorizontalDragEnd: (details) =>
          _tracker.end(details.velocity.pixelsPerSecond.dx * back),
      onHorizontalDragCancel: () => _tracker.end(0),
      child: widget.child,
    );
  }
}

/// Horizontal pager in reading order — in the Arabic (RTL) layout, swipe →
/// for the next page and ← for the previous one. On the first page, ← drags
/// the whole screen away back to the previous one; the last page bounces.
class SwipeBackPageView extends StatefulWidget {
  const SwipeBackPageView({
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChanged,
    this.swipeEnabled = true,
    super.key,
  });

  final PageController controller;
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onPageChanged;

  /// False while a page needs horizontal drags itself (panning a zoomed-in
  /// manuscript): paging and swiping back both stand aside.
  final bool swipeEnabled;

  @override
  State<SwipeBackPageView> createState() => _SwipeBackPageViewState();
}

class _SwipeBackPageViewState extends State<SwipeBackPageView> {
  final _tracker = _SwipeBackTracker();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tracker.route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: widget.controller,
      // The swipe-back physics must be outermost to see every release, so
      // it brings its own page snapping.
      pageSnapping: false,
      physics: widget.swipeEnabled
          ? OverscrollHandoffPhysics(
              _tracker,
              parent: const PageScrollPhysics(),
            )
          : const NeverScrollableScrollPhysics(),
      itemCount: widget.itemCount,
      onPageChanged: widget.onPageChanged,
      itemBuilder: widget.itemBuilder,
    );
  }
}

/// Hands a pager's drags past its first page to [tracker] instead of
/// overscrolling, and keeps the pager on that page while [tracker] follows
/// the finger.
///
/// It must see every release, so it goes outermost: the pager turns
/// `pageSnapping` off and passes [PageScrollPhysics] as [parent].
///
/// Positive user offsets head toward the first page. With the pager in the
/// ambient text direction, that's the side the route slides off to (and
/// the side menu slides in from).
class OverscrollHandoffPhysics extends ScrollPhysics {
  const OverscrollHandoffPhysics(this.tracker, {super.parent});

  final OverscrollTracker tracker;

  @override
  OverscrollHandoffPhysics applyTo(ScrollPhysics? ancestor) =>
      OverscrollHandoffPhysics(tracker, parent: buildParent(ancestor));

  /// A single page can't scroll, but must still take drags to hand over.
  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (tracker.isTracking) {
      return _toPager(position, tracker.update(offset));
    }
    final room = position.pixels - position.minScrollExtent;
    // Also leaves a bounce already past the first page to the parent.
    if (offset <= room || room < 0) {
      return super.applyPhysicsToUserOffset(position, offset);
    }
    // The pager scrolls to its first page; the tracker takes the rest.
    return _toPager(position, room + tracker.update(offset - room));
  }

  /// The parent never sees a zero offset: iOS's bouncing physics asserts on
  /// it, and a drag the tracker is following hands the pager nothing.
  double _toPager(ScrollMetrics position, double offset) =>
      offset == 0 ? 0 : super.applyPhysicsToUserOffset(position, offset);

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (tracker.isTracking) {
      // Positive scroll velocity heads to later pages, away from the tracker.
      tracker.end(-velocity);
      return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
