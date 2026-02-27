import 'package:flutter/material.dart';
import 'package:tarumt_carpool/screens/driver_verification/admin/driver_verification_list_page.dart';
import 'package:tarumt_carpool/screens/reviews/admin/review_list_screen.dart';
import 'admin_reports_screen.dart';
import 'package:tarumt_carpool/screens/profile/dashboard/admin_profile_dashboard.dart';

class AdminTabScaffold extends StatefulWidget {
  const AdminTabScaffold({super.key});

  @override
  State<AdminTabScaffold> createState() => _AdminTabScaffoldState();
}

class _AdminTabScaffoldState extends State<AdminTabScaffold> {
  static const primary = Color(0xFF1E73FF);

  int _index = 0;
  final PageController _pageCtrl = PageController(initialPage: 0);

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onNavTap(int i) {
    setState(() => _index = i);
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: PageView(
          controller: _pageCtrl,
          onPageChanged: (i) => setState(() => _index = i),
          children: [
            const DriverVerificationListPage(),
            const AdminReviewListScreen(),
            const AdminReportsScreen(),
            AdminProfileDashboard(), // ✅ no const here
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primary,
        unselectedItemColor: Colors.black54,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.verified_user_outlined),
              label: 'Drivers'),
          BottomNavigationBarItem(
              icon: Icon(Icons.rate_review_outlined),
              label: 'Reviews'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              label: 'Reports'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile'),
        ],
      ),
    );
  }
}