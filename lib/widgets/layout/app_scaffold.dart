import 'package:flutter/material.dart';
import 'package:tarumt_carpool/theme/app_colors.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),  // entire page background color
      appBar: AppBar(
        backgroundColor: AppColors.brandBlue, // app bar background color
        foregroundColor: Colors.white, // app bar foreground color
        title: Text(title),
      ),
      body: child,
    );
  }
}
