import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePopUpMenu extends StatelessWidget {
  const HomePopUpMenu({super.key});

  PopupMenuItem<String> _buildPopupMenuItem(
      String route, String title, IconData icon) {
    return PopupMenuItem<String>(
      value: route,
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Text(title)
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      offset: const Offset(10, 10),
      tooltip: 'القائمة',
      enableFeedback: true,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      icon: const Icon(Icons.menu),
      initialValue: '',
      onSelected: (route) {
        context.push(route);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        _buildPopupMenuItem('/settings', 'الإعدادات', Icons.settings),
        _buildPopupMenuItem('/social', 'الصفحات الرسمية', Icons.link)
        // TODO: about tareeqa
        // const PopupMenuItem<String>(
        //   value: 'about',
        //   child: Text('Item 3'),
        // ),
      ],
    );
  }
}
