import 'package:flutter/material.dart';

void showSnackBar(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(milliseconds: 700),
      content: Directionality( // Wrap content with Directionality
        textDirection: TextDirection.rtl, // Set text direction to RTL
        child: Text(msg),
      ),
    ),
  );
}
