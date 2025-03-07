import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:yosria/audioPlayer/audioPlayer.dart';

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

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.put(Controller());

    // ever(c.url, (url) {
    //   print('changed $url');
    // });

    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 1000, maxHeight: 1000),
              child: Column(
                children: [
                  Expanded(
                    child: widget.navigationShell,
                  ),
                  Obx(() {
                    if (c.url.value != '') {
                      return const AudioControllerWidget();
                    } else {}
                    return Container();
                  }),
                ],
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            indicatorShape: const StadiumBorder(),
            destinations: const [
              NavigationDestination(
                  // TODO: theme color here instead
                  selectedIcon: Icon(Icons.home, color: Colors.green),
                  icon: Icon(Icons.home_outlined),
                  label: 'الرئيسية'),
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
              // NavigationDestination(
              //     selectedIcon: Icon(Icons.info, color: Colors.green),
              //     icon: Icon(Icons.info_outline_rounded),
              //     label: 'عن الطريقة'),
            ],
            onDestinationSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
              _goBranch(selectedIndex);
            },
            selectedIndex: selectedIndex,
          ),
        ));
  }
}
