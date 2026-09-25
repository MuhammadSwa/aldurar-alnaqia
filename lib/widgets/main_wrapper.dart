import 'package:aldurar_alnaqia/audio/widgets/audio_mini_player.dart';
import 'package:aldurar_alnaqia/widgets/my_drawer.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

final rootScaffoldKey = GlobalKey<ScaffoldState>(debugLabel: 'rootDrawer');

/// Places the shared audio controls below a fullscreen route.
///
/// Routes hosted by the root navigator sit above [MainWrapper], so they do
/// not inherit its mini player. Wrap a fullscreen reader with this to keep
/// playback controls without restoring the bottom navigation.
///
/// Layout: `Expanded(child)` on top, [AudioMiniPlayer] pinned below. When
/// no track is loaded the player collapses to [SizedBox.shrink].
class AudioMiniPlayerOverlay extends StatelessWidget {
  const AudioMiniPlayerOverlay({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(child: child),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: const AudioMiniPlayer(),
            ),
          ),
        ],
      ),
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
            // Simple vertical layout: screen content on top, mini player
            // (a no-op SizedBox.shrink when nothing is loaded) below it,
            // and the NavigationBar under that via bottomNavigationBar.
            // The surrounding Scaffold paints any leftover space, so no
            // black strip can appear here.
            body: Column(
              children: [
                Expanded(child: navigationShell),
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
              onDestinationSelected: goBranch,
              selectedIndex: navigationShell.currentIndex,
            ),
          ),
        ),
      ),
    );
  }
}
