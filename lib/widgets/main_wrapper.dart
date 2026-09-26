import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/widgets/audio_mini_player.dart';
import 'package:aldurar_alnaqia/router/swipe_back.dart';
import 'package:aldurar_alnaqia/widgets/my_drawer.dart';
import 'package:aldurar_alnaqia/widgets/swipe_drawer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Places the shared audio controls below a fullscreen route.
///
/// Routes hosted by the root navigator sit above [MainWrapper], so they do
/// not inherit its mini player. Wrap a fullscreen reader with this to keep
/// playback controls without restoring the bottom navigation.
///
/// Layout: `Expanded(child)` on top, [AudioMiniPlayer] pinned below. When
/// no track is loaded the player collapses to [SizedBox.shrink].
///
/// Both run to the bottom edge of the screen. The player, when shown, fills
/// the home-indicator area with its own background; otherwise [child] runs
/// under it and keeps the bottom inset to pad its content.
class AudioMiniPlayerOverlay extends ConsumerWidget {
  const AudioMiniPlayerOverlay({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerVisible = ref.watch(audioProvider.select((s) => s.isVisible));
    return Column(
      children: [
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: playerVisible,
            child: child,
          ),
        ),
        const AudioMiniPlayer(),
      ],
    );
  }
}

/// The bottom-nav shell: the tabs sit side by side in a pager, in the
/// NavigationBar's order, so a swipe moves between them. Swiping past the
/// home tab, toward the leading edge (the right in Arabic), pulls out the
/// side menu.
///
/// Built by go_router as the container of the tab branches' navigators
/// ([children]); the router's branch index stays the source of truth. A
/// swipe switches branch once it settles on a tab, and a branch switch from
/// anywhere else (a NavigationBar tap, a `go()`) moves the pager.
class MainWrapper extends StatefulWidget {
  const MainWrapper({
    required this.navigationShell,
    required this.children,
    required this.isTabRoot,
    super.key,
  });
  final StatefulNavigationShell navigationShell;

  /// The branches' navigators, in branch order.
  final List<Widget> children;

  /// Whether the current tab shows its own screen. Screens pushed inside a
  /// tab take a swipe as "back", so only the tab screens themselves swipe
  /// between tabs and open the drawer (the menu button always works).
  final bool isTabRoot;

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  late final _pageController =
      PageController(initialPage: widget.navigationShell.currentIndex);

  /// The tab the pager shows most of. The NavigationBar follows it, so its
  /// selection moves mid-swipe, before the branch switches.
  late int _page = widget.navigationShell.currentIndex;

  /// The tabs the pager has in view: the one it rests on, or the two a
  /// swipe is between. Only their tickers run.
  late ({int first, int last}) _inView = (first: _page, last: _page);

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(MainWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.navigationShell.currentIndex;
    if (index != oldWidget.navigationShell.currentIndex && index != _page) {
      _page = index;
      if (_pageController.hasClients) _pageController.jumpToPage(index);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goBranch(int index) {
    final shell = widget.navigationShell;
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  void _onPageChanged(int page) {
    if (page != _page) setState(() => _page = page);
  }

  void _onScroll() {
    var page = _pageController.page;
    if (page == null) return;
    // Resting on a tab can leave the page a hair off it (see _onScrollEnd).
    if ((page - page.round()).abs() < 1e-6) page = page.roundToDouble();
    final inView = (first: page.floor(), last: page.ceil());
    if (inView != _inView) setState(() => _inView = inView);
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    final page = _pageController.page;
    if (notification.depth != 0 || page == null) return false;
    final tab = page.round();
    // Only once it rests on a tab: a finger catching the pager mid-flight
    // also ends the scroll, and switching branch there could take the swipe
    // away (the tab it lands on may have a screen pushed on it).
    if ((page - tab).abs() < 1e-6 &&
        tab != widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(tab);
    }
    return false;
  }

  /// Built below the drawer, to hand it the pager's drags past home.
  Widget _buildPager(BuildContext context) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: _onScrollEnd,
      child: PageView(
        controller: _pageController,
        // The drawer drag must be outermost to see every release, so it
        // brings its own page snapping.
        pageSnapping: false,
        physics: widget.isTabRoot
            ? OverscrollHandoffPhysics(
                SwipeDrawer.of(context).overscrollTracker,
                parent: const PageScrollPhysics(),
              )
            : const NeverScrollableScrollPhysics(),
        onPageChanged: _onPageChanged,
        children: [
          // As in go_router's IndexedStack container, a tab out of view
          // stops its tickers. It restarts them as soon as a swipe brings
          // it into view, not once the swipe settles: animations it missed
          // offscreen then finish at once. Otherwise a theme change shows
          // mid-swipe with the old text color, as Material fades text
          // color but switches backgrounds instantly.
          for (final (index, child) in widget.children.indexed)
            TickerMode(
              enabled: index >= _inView.first && index <= _inView.last,
              child: child,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Selected tab icon color contrasts with the primary indicator pill.
    final selectedIconColor = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 1000),
          child: SwipeDrawer(
            drawer: const MyDrawer(),
            child: Scaffold(
              // Keep the bottom NavigationBar pinned: the keyboard overlays
              // it instead of lifting it above the keyboard.
              resizeToAvoidBottomInset: false,
              body: Column(
                children: [
                  Expanded(child: Builder(builder: _buildPager)),
                  const AudioMiniPlayer(),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                indicatorShape: const StadiumBorder(),
                destinations: [
                  NavigationDestination(
                    selectedIcon: Icon(Icons.home, color: selectedIconColor),
                    icon: const Icon(Icons.home_outlined),
                    label: 'الرئيسية',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.timer_outlined),
                    selectedIcon: Icon(Icons.timer, color: selectedIconColor),
                    label: 'مواقيت الصلاة',
                  ),
                  NavigationDestination(
                    selectedIcon: Icon(Icons.list, color: selectedIconColor),
                    icon: const Icon(Icons.list_outlined),
                    label: 'الأوراد',
                  ),
                  NavigationDestination(
                    selectedIcon: Icon(Icons.book, color: selectedIconColor),
                    icon: const Icon(Icons.book_outlined),
                    label: 'المكتبة',
                  ),
                ],
                onDestinationSelected: _goBranch,
                selectedIndex: _page,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
