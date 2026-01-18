import 'package:flutter/material.dart';
import 'admin_home_content.dart';
import '../profile/dashboard/admin_profile_dashboard.dart';

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
            const AdminHomeContent(),            // can stay const
            const SuspiciousReviewContent(),     // can stay const (if your widget is const)
            const _PlaceholderTab(title: 'Notifications'),
            AdminProfileDashboard(),             // ✅ NOT const
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
          BottomNavigationBarItem(icon: Icon(Icons.verified_user_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.rate_review_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
        ],
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String title;
  const _PlaceholderTab({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.black54,
        ),
      ),
    );
  }
}
