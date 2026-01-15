import 'package:flutter/material.dart';
import 'rider_home_content.dart';

class RiderHomePage extends StatelessWidget {
  const RiderHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
      body: SafeArea(
        child: RiderHomeContent(),
      ),
    );
  }
}
