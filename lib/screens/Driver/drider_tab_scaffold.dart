import 'package:flutter/material.dart';
import 'package:tarumt_carpool/screens/Driver/driver_home_page.dart';
import '../profile/dashboard/driver_profile_dashboard.dart';
class DriverTabScaffold extends StatefulWidget {
  const DriverTabScaffold({super.key});

  @override
  State<DriverTabScaffold> createState() => _DriverTabScaffoldState();
}

class _DriverTabScaffoldState extends State<DriverTabScaffold> {
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
            const DriverHomePage(),                 // ✅ can be const
            const _PlaceholderTab(title: 'My Rides'),
            const _PlaceholderTab(title: 'Notifications'),
            DriverProfileDashboard(),               // ✅ NOT const
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
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: ''),
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
