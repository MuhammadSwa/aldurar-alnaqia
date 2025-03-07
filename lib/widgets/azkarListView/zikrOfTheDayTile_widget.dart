import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ZikrOfTheDayTile extends StatelessWidget{
  const ZikrOfTheDayTile({super.key, required this.title, required this.route});
  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      leading: const Icon(Icons.today_rounded),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        context.go(route);
      },
    );
  }
}
