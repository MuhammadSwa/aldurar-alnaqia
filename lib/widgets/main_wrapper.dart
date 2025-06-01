import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:aldurar_alnaqia/audioPlayer/audioPlayer.dart';

class GlobalDrawerController extends GetxController {
  final List<GlobalKey<ScaffoldState>> _scaffoldKeys = [];

  // Register a scaffold key
  void registerScaffoldKey(GlobalKey<ScaffoldState> key) {
    if (!_scaffoldKeys.contains(key)) {
      _scaffoldKeys.add(key);
    }
  }

  // Unregister a scaffold key
  void unregisterScaffoldKey(GlobalKey<ScaffoldState> key) {
    _scaffoldKeys.remove(key);
  }

bool hasOpenDrawer() {
    for (final key in _scaffoldKeys) {
      if (key.currentState?.isDrawerOpen == true) {
        return true;
      }
    }
    return false;
  }

  // Close all open drawers
  void closeAllDrawers() {
    for (final key in _scaffoldKeys) {
      if (key.currentState?.isDrawerOpen == true) {
        Navigator.of(key.currentContext!).pop();
      }
    }

    // for (final key in _scaffoldKeys) {
    //   if (key.currentState?.isDrawerOpen == true) {
    //     key.currentState?.closeDrawer();
    //   }
    // }
  }

  @override
  void onClose() {
    _scaffoldKeys.clear();
    super.onClose();
  }
}

class MainWrapper extends StatefulWidget {
  const MainWrapper({
    required this.navigationShell,
    super.key,
  });
  final StatefulNavigationShell navigationShell;
  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize the global drawer controller early
    Get.lazyPut(() => GlobalDrawerController());
  }

  void _goBranch(int index) async {
    // Get the drawer controller and close all drawers before navigating
    try {
      final drawerController = Get.find<GlobalDrawerController>();

      if (drawerController.hasOpenDrawer()) {
        // Close instantly without animation to avoid flickering
        drawerController.closeAllDrawers();
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      print('GlobalDrawerController not found: $e');
    }

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.put(Controller());
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 1000),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: Column(
                  children: [
                    Expanded(
                      child: widget.navigationShell,
                    ),
                    Obx(() {
                      if (c.url.value.isNotEmpty) {
                        return const AudioControllerWidget();
                      } else {
                        return Container();
                      }
                    }),
                  ],
                ),
              ),
              bottomNavigationBar: NavigationBar(
                indicatorShape: const StadiumBorder(),
                destinations: const [
                  NavigationDestination(
                      selectedIcon: Icon(Icons.home, color: Colors.green),
                      icon: Icon(Icons.home_outlined),
                      label: 'الرئيسية'),
                  NavigationDestination(
                      icon: Icon(Icons.timer_outlined),
                      selectedIcon: Icon(Icons.timer, color: Colors.green),
                      label: 'مواقيت الصلاة'),
                  NavigationDestination(
                      selectedIcon: Icon(Icons.list, color: Colors.green),
                      icon: Icon(Icons.list_outlined),
                      label: 'الأوراد'),
                  NavigationDestination(
                      selectedIcon: Icon(Icons.book, color: Colors.green),
                      icon: Icon(Icons.book_outlined),
                      label: 'المكتبة'),
                ],
                onDestinationSelected: (index) {
                  setState(() {
                    selectedIndex = index;
                  });
                  _goBranch(selectedIndex);
                },
                selectedIndex: selectedIndex,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
