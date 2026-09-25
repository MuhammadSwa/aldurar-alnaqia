import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/widgets/audio_mini_player.dart';
import 'package:aldurar_alnaqia/widgets/my_drawer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

final rootScaffoldKey = GlobalKey<ScaffoldState>(debugLabel: 'rootDrawer');

/// Places the shared audio controls over a fullscreen route.
///
/// Routes hosted by the root navigator sit above [MainWrapper], so they do
/// not inherit its mini player. Use this around a fullscreen reader that
/// should retain playback controls without restoring the bottom navigation.
///
/// Content is NOT padded down; instead the player's clearance is injected
/// into [MediaQueryData.padding.bottom], so scrollables absorb it as
/// scrollable bottom padding and paint edge-to-edge underneath the player.
class AudioMiniPlayerOverlay extends ConsumerWidget {
  const AudioMiniPlayerOverlay({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlayerVisible = ref.watch(
      audioProvider.select((state) => state.isVisible),
    );
    final isPlayerCollapsed = ref.watch(miniPlayerCollapsedProvider);
    final playerClearance = miniPlayerClearance(
      visible: isPlayerVisible,
      collapsed: isPlayerCollapsed,
    );

    final mq = MediaQuery.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: playerClearance),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          builder: (context, animatedClearance, child) => MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(bottom: animatedClearance),
            ),
            child: child!,
          ),
          child: child,
        ),
        SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: const AudioMiniPlayer(),
            ),
          ),
        ),
      ],
    );
  }
}

class MainWrapper extends ConsumerWidget {
  const MainWrapper({
    required this.navigationShell,
    super.key,
  });
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void goBranch(int index) {
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    // Selected tab icon color contrasts with the primary indicator pill.
    final selectedIconColor = Theme.of(context).colorScheme.onPrimary;

    final isPlayerVisible = ref.watch(
      audioProvider.select((state) => state.isVisible),
    );
    final isPlayerCollapsed = ref.watch(miniPlayerCollapsedProvider);
    final playerClearance = miniPlayerClearance(
      visible: isPlayerVisible,
      collapsed: isPlayerCollapsed,
    );

    final mq = MediaQuery.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 1000),
          child: Scaffold(
            key: rootScaffoldKey,
            drawer: const MyDrawer(),
            // Keep the bottom NavigationBar pinned: the keyboard overlays
            // it instead of lifting it above the keyboard.
            resizeToAvoidBottomInset: false,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // Content fills the full height and scrolls BEHIND the
                // floating mini player. The clearance travels via
                // MediaQuery.padding.bottom, so ListViews/GridViews
                // (which default to MediaQuery padding) end their items
                // above the player while their background extends to the
                // screen edge — no reserved empty strip is visible.
                TweenAnimationBuilder<double>(
                  tween: Tween(end: playerClearance),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedClearance, child) => MediaQuery(
                      data: mq.copyWith(
                        padding: mq.padding.copyWith(bottom: animatedClearance),
                      ),
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.primary,
                        child: child,
                      )),
                  child: navigationShell,
                ),
                // Floating card stacked over the content, pinned just
                // above the NavigationBar. AudioMiniPlayer collapses to
                // SizedBox.shrink internally when nothing is loaded.
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: AudioMiniPlayer(),
                ),
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
              onDestinationSelected: goBranch,
              selectedIndex: navigationShell.currentIndex,
            ),
          ),
        ),
      ),
    );
  }
}
