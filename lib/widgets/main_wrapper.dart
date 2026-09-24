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
class AudioMiniPlayerOverlay extends ConsumerWidget {
  const AudioMiniPlayerOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlayerVisible = ref.watch(
      audioProvider.select((state) => state.isVisible),
    );
    final isPlayerCollapsed = ref.watch(miniPlayerCollapsedProvider);
    // The player is positioned above the system bottom inset. Match that
    // inset in the reader body so every kind of content, including PDFs,
    // can scroll clear of the overlay.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final playerClearance = !isPlayerVisible
        ? 0.0
        : (isPlayerCollapsed ? 64.0 : 166.0) + bottomInset;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: playerClearance),
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

class MainWrapper extends StatelessWidget {
  const MainWrapper({
    required this.navigationShell,
    super.key,
  });
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    void goBranch(int index) {
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    // Selected tab icon color contrasts with the primary indicator pill.
    final selectedIconColor = Theme.of(context).colorScheme.onPrimary;

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
            body: Center(
              child: Column(
                children: [
                  Expanded(
                    child: navigationShell,
                  ),
                  // The AudioMiniPlayer widget internally watches audio state and collapses to
                  // SizedBox.shrink when nothing is loaded.
                  const AudioMiniPlayer(),
                ],
              ),
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
