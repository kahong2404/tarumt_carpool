import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tarumt_carpool/repositories/ride_repository.dart';
import 'package:tarumt_carpool/screens/Rider/rider_home_content.dart';
import 'package:tarumt_carpool/screens/Rider/rider_my_ride_screen.dart';
import 'package:tarumt_carpool/screens/Rider/rider_notification_screen.dart';
import 'package:tarumt_carpool/screens/Rider/rider_trip_map_screen.dart';
import '../profile/dashboard/rider_profile_dashboard.dart';
class RiderTabScaffold extends StatefulWidget {
  const RiderTabScaffold({super.key});

  @override
  State<RiderTabScaffold> createState() => _RiderTabScaffoldState();
}

class _RiderTabScaffoldState extends State<RiderTabScaffold> {
  static const primary = Color(0xFF1E73FF);

  int _index = 0;
  final PageController _pageCtrl = PageController(initialPage: 0);
  final _auth = FirebaseAuth.instance;
  final _rideRepo = RideRepository();

  bool _autoResumeChecked = false;
  bool _autoResumeNavigated = false;

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoResumeIfNeeded());
  }

  Future<void> _autoResumeIfNeeded() async {
    if (_autoResumeChecked || _autoResumeNavigated) return;
    _autoResumeChecked = true;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final rideId = await _rideRepo.getRiderActiveRideIdOnce(uid);
      if (!mounted) return;
      if (rideId == null) return;

      _autoResumeNavigated = true;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RiderTripMapScreen(rideId: rideId),
        ),
      );
    } catch (_) {
      // ignore - do not block app launch
    }
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
            const RiderHomeContent(),                // Tab 0
            RiderMyRidesScreen(),// Tab 1
            RiderNotificationsScreen(),
            RiderProfileDashboard(),                 // ✅ Tab 3 (Profile)
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
