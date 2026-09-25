import 'package:aldurar_alnaqia/common/reader/reader_chrome_controller.dart';
import 'package:material_ui/material_ui.dart';

/// Intent emitted by embedded reader content (PDF view, text view, …) that
/// wants to drive the reader's AppBar.
enum ReaderChromeAction { toggle, hide, show }

/// Lets embedded reader content control the containing reader's AppBar.
class ReaderChromeNotification extends Notification {
  const ReaderChromeNotification(this.action);

  final ReaderChromeAction action;
}

/// Reader chrome shared by every reading screen (azkar text, Hilya/Sanad
/// manuscripts, books).
///
/// Chrome policy is orientation-aware and lives in
/// [ReaderChromeController], shared with the book viewer — embedded content
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
  /// Unified chrome state shared with the book viewer. The notification and
  /// scroll handlers below only translate content intent into it.
  late final ReaderChromeController _chrome;

  @override
  void initState() {
    super.initState();
    _chrome = ReaderChromeController();
    _chrome.addListener(_onChromeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery.orientationOf registers the dependency: this runs on every
    // rotation and a build always follows.
    _chrome.updateOrientation(
      MediaQuery.orientationOf(context) == Orientation.landscape,
    );
  }

  @override
  void dispose() {
    _chrome.removeListener(_onChromeChanged);
    _chrome.dispose();
    super.dispose();
  }

  void _onChromeChanged() {
    if (mounted) setState(() {});
  }

  bool _handleChromeIntent(ReaderChromeNotification notification) {
    if (!_chrome.landscape) {
      return false; // Fixed bar in portrait: ignore intents.
    }
    switch (notification.action) {
      case ReaderChromeAction.toggle:
        _chrome.toggle();
      case ReaderChromeAction.hide:
        _chrome.hide();
      case ReaderChromeAction.show:
        _chrome.show();
    }
    return true;
  }

  bool _handleScroll(ScrollNotification notification) {
    if (!_chrome.landscape) return false; // Fixed bar in portrait.
    // The outer PageView also emits scroll notifications; only the vertical
    // reader scroll should affect the chrome.
    if (notification.metrics.axis != Axis.vertical) return false;

    // Pull-down overscroll at the very top (finger drags down while already
    // at offset 0): reveal even if metrics haven't settled exactly on
    // minScrollExtent.
    if (notification is OverscrollNotification && notification.overscroll < 0) {
      _chrome.show();
      return false;
    }
    if (notification.metrics.pixels <= notification.metrics.minScrollExtent) {
      _chrome.show();
    } else if (notification is ScrollUpdateNotification &&
        notification.scrollDelta != 0) {
      _chrome.hide();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final showAppBar = _chrome.visible;

    return NotificationListener<ReaderChromeNotification>(
      onNotification: _handleChromeIntent,
      child: Scaffold(
        appBar: showAppBar
            ? AppBar(title: Text(widget.title), actions: widget.actions)
            : null,
        body: SafeArea(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScroll,
            // Keep this wrapper in the tree in both orientations. Adding or
            // removing it on rotation would recreate a nested PageView, making
            // a slidable zikr return to its initial page. With a null callback
            // it registers no tap gesture in portrait, so it stays inert there.
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _chrome.landscape ? _chrome.toggle : null,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
