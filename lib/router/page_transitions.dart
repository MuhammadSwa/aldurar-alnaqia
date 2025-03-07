import 'package:flutter/material.dart';

SlideTransition slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child) {
  return SlideTransition(
    position:
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
      CurvedAnimation(
          parent: animation, curve: Curves.easeInOutCubicEmphasized),
    ),
    child: FadeTransition(
      opacity: animation,
      child: child,
    ),
  );
}
