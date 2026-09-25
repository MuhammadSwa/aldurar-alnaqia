import 'package:aldurar_alnaqia/router/swipe_back.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

// Material's drawer values (see DrawerController).
const Duration _kSettleDuration = Duration(milliseconds: 246);
const double _kMinFlingVelocity = 365;
const double _kDefaultWidth = 304;

/// Side menu over [child], in place of [Scaffold.drawer].
///
/// Scaffold's drawer keeps its drag to itself, so the tab pager couldn't
/// open it from a swipe. This one takes the pager's drags past the home tab
/// ([overscrollTracker]) and slides in under the finger. Otherwise it works
/// the same way: the scrim, a swipe back toward its edge, the back button
/// and `Navigator.pop` all close it (the last two through a local history
/// entry on the enclosing route).
class SwipeDrawer extends StatefulWidget {
  const SwipeDrawer({required this.drawer, required this.child, super.key});

  final Widget drawer;
  final Widget child;

  /// The drawer enclosing [context]; the tab screens' menu buttons call
  /// `SwipeDrawer.of(context).open()`.
  static SwipeDrawerState of(BuildContext context) =>
      context.findAncestorStateOfType<SwipeDrawerState>()!;

  @override
  State<SwipeDrawer> createState() => SwipeDrawerState();
}

class SwipeDrawerState extends State<SwipeDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: _kSettleDuration,
    vsync: this,
  )
    ..addListener(_rebuild)
    ..addStatusListener(_updateHistoryEntry);

  final GlobalKey _drawerKey = GlobalKey();
  final _focusScopeNode = FocusScopeNode();
  LocalHistoryEntry? _historyEntry;

  /// Opens the drawer with a pager's drags past its first page.
  late final OverscrollTracker overscrollTracker = _PagerDrag(this);

  void open() => _controller.fling();

  void close() => _controller.fling(velocity: -1);

  @override
  void dispose() {
    _removeHistoryEntry();
    _controller.dispose();
    _focusScopeNode.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  double get _width {
    final box = _drawerKey.currentContext?.findRenderObject() as RenderBox?;
    // Until the drawer first lays out, Material's default width.
    return box?.size.width ?? _kDefaultWidth;
  }

  /// 1 when a drag to the right opens the drawer, -1 when it closes it. It
  /// slides in from the leading edge: the right in the Arabic layout.
  double get _openDirection =>
      Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  void _move(DragUpdateDetails details) {
    _controller.value += details.primaryDelta! / _width * _openDirection;
  }

  /// Opens or closes the drawer from where a drag left it; [velocity] is
  /// the release speed toward open, in pixels per second.
  void _settle(double velocity) {
    if (_controller.isDismissed) return;
    if (velocity.abs() >= _kMinFlingVelocity) {
      _controller.fling(velocity: velocity / _width);
    } else if (_controller.value < 0.5) {
      close();
    } else {
      open();
    }
  }

  // While the drawer is open or opening, the back button and Navigator.pop
  // close it rather than the screen under it.

  void _updateHistoryEntry(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
      case AnimationStatus.completed:
        _addHistoryEntry();
      case AnimationStatus.reverse:
      case AnimationStatus.dismissed:
        _removeHistoryEntry();
    }
  }

  void _addHistoryEntry() {
    if (_historyEntry != null) return;
    final route = ModalRoute.of(context);
    if (route == null) return;
    final entry = _historyEntry = LocalHistoryEntry(
      onRemove: _handleHistoryEntryRemoved,
      impliesAppBarDismissal: false,
    );
    route.addLocalHistoryEntry(entry);
    FocusScope.of(context).setFirstFocus(_focusScopeNode);
  }

  void _removeHistoryEntry() {
    final entry = _historyEntry;
    _historyEntry = null;
    entry?.remove();
  }

  void _handleHistoryEntryRemoved() {
    // Still set: a pop removed it, not the drawer closing.
    if (_historyEntry == null) return;
    _historyEntry = null;
    close();
  }

  @override
  Widget build(BuildContext context) {
    // Always a Stack, so opening the drawer never re-parents the app.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_controller.isDismissed) _buildDrawer(context),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final scrimColor = DrawerTheme.of(context).scrimColor ?? Colors.black54;
    return GestureDetector(
      onHorizontalDragDown: (_) => _controller.stop(),
      onHorizontalDragUpdate: _move,
      onHorizontalDragEnd: (details) =>
          _settle(details.velocity.pixelsPerSecond.dx * _openDirection),
      onHorizontalDragCancel: () => _settle(0),
      excludeFromSemantics: true,
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            BlockSemantics(
              child: ExcludeSemantics(
                // On Android, the back button dismisses it instead.
                excluding: defaultTargetPlatform == TargetPlatform.android,
                child: GestureDetector(
                  onTap: close,
                  child: Semantics(
                    label: MaterialLocalizations.of(context)
                        .modalBarrierDismissLabel,
                    child: ColoredBox(
                      color: scrimColor.withValues(
                        alpha: scrimColor.a * _controller.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                widthFactor: _controller.value,
                child: RepaintBoundary(
                  child: FocusScope(
                    key: _drawerKey,
                    node: _focusScopeNode,
                    child: widget.drawer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the drawer with a pager's drags past its first page: at the home
/// tab, a swipe toward the drawer's edge pulls it out.
class _PagerDrag implements OverscrollTracker {
  _PagerDrag(this._drawer);

  final SwipeDrawerState _drawer;

  @override
  bool isTracking = false;

  @override
  double update(double delta) {
    final controller = _drawer._controller;
    if (!isTracking) {
      if (delta <= 0) return delta;
      isTracking = true;
      controller.stop();
    }
    final width = _drawer._width;
    final before = controller.value;
    final after = (before + delta / width).clamp(0.0, 1.0);
    controller.value = after;
    if (after > 0 || delta >= 0) return 0;
    // Pushed shut again: the rest moves the pager.
    isTracking = false;
    return delta - (after - before) * width;
  }

  @override
  void end(double velocity) {
    if (!isTracking) return;
    isTracking = false;
    _drawer._settle(velocity);
  }
}
