import 'package:material_ui/material_ui.dart';

/// Intent emitted by embedded reader content (PDF view, text view, …) that
/// wants to drive the reader's AppBar.
enum ReaderChromeAction { toggle, hide }

/// Lets embedded reader content control the containing reader's AppBar.
class ReaderChromeNotification extends Notification {
  const ReaderChromeNotification(this.action);

  final ReaderChromeAction action;
}

/// Reader chrome shared by every reading screen (azkar text, Hilya/Sanad
/// manuscripts, books).
///
/// Chrome policy is orientation-aware and lives *here* — embedded content
/// never branches on orientation, it just dispatches
/// [ReaderChromeNotification]s, which are ignored in portrait:
///
///  * **Portrait**  – fixed [AppBar], like a normal screen. No tap-to-toggle,
///    no hide-on-scroll, and no gesture wrapper over the content.
///  * **Landscape** – immersive reading: the bar hides as soon as vertical
///    scrolling starts, tapping the page toggles it, and scrolling back to
///    the top reveals it again.
class ReaderScaffold extends StatefulWidget {
  const ReaderScaffold({
    required this.title,
    required this.child,
    this.actions = const [],
    super.key,
  });

  final String title;
  final List<Widget> actions;

  /// Reader body. May itself be a scrollable, a PDF view, or a PageView.
  final Widget child;

  @override
  State<ReaderScaffold> createState() => _ReaderScaffoldState();
}

class _ReaderScaffoldState extends State<ReaderScaffold> {
  /// Cached in [didChangeDependencies]; the notification handlers run outside
  /// build, so they only read the field.
  bool _landscape = false;

  /// Only meaningful while immersive (landscape); portrait always shows.
  bool _appBarVisible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery.orientationOf registers the dependency: this runs on every
    // rotation and a build always follows, so plain assignment is enough.
    _landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    // Leaving landscape: restore state so rotating back starts visible
    // instead of staying stuck hidden.
    if (!_landscape) _appBarVisible = true;
  }

  void _showAppBar() {
    if (!_appBarVisible && mounted) setState(() => _appBarVisible = true);
  }

  void _hideAppBar() {
    if (_appBarVisible && mounted) setState(() => _appBarVisible = false);
  }

  void _toggleAppBar() {
    if (mounted) setState(() => _appBarVisible = !_appBarVisible);
  }

  bool _handleChromeIntent(ReaderChromeNotification notification) {
    if (!_landscape) return false; // Fixed bar in portrait: ignore intents.
    switch (notification.action) {
      case ReaderChromeAction.toggle:
        _toggleAppBar();
      case ReaderChromeAction.hide:
        _hideAppBar();
    }
    return true;
  }

  bool _handleScroll(ScrollNotification notification) {
    if (!_landscape) return false; // Fixed bar in portrait.
    // The outer PageView also emits scroll notifications; only the vertical
    // reader scroll should affect the chrome.
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification.metrics.pixels <= notification.metrics.minScrollExtent) {
      _showAppBar();
    } else if (notification is ScrollUpdateNotification &&
        notification.scrollDelta != 0) {
      _hideAppBar();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final showAppBar = !_landscape || _appBarVisible;

    return NotificationListener<ReaderChromeNotification>(
      onNotification: _handleChromeIntent,
      child: Scaffold(
        appBar: showAppBar
            ? AppBar(title: Text(widget.title), actions: widget.actions)
            : null,
        body: NotificationListener<ScrollNotification>(
          onNotification: _handleScroll,
          // Only wrap in a tap detector while immersive. In portrait the
          // content gets no gesture wrapper at all, so nothing competes with
          // text selection or the PDF view.
          child: _landscape
              ? GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleAppBar,
                  child: widget.child,
                )
              : widget.child,
        ),
      ),
    );
  }
}
