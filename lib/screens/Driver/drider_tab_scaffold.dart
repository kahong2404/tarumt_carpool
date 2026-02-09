import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tarumt_carpool/repositories/ride_repository.dart';
import 'package:tarumt_carpool/screens/Driver/driver_home_page.dart';
// import 'package:tarumt_carpool/screens/Driver/driver_my_ride_screen.dart';
import 'package:tarumt_carpool/screens/Driver/driver_trip_map_screen.dart';
import '../profile/dashboard/driver_profile_dashboard.dart';
import 'package:tarumt_carpool/screens/Driver/driver_request_list_screen.dart';

class DriverTabScaffold extends StatefulWidget {
  const DriverTabScaffold({super.key});

  @override
  State<DriverTabScaffold> createState() => _DriverTabScaffoldState();
}

class _DriverTabScaffoldState extends State<DriverTabScaffold> {
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
      final rideId = await _rideRepo.getDriverActiveRideIdOnce(uid);
      if (!mounted) return;
      if (rideId == null) return;

      _autoResumeNavigated = true;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverTripMapScreen(rideId: rideId),
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
            const DriverHomePage(),                 // ✅ can be const
            // DriverMyRidesPage(),
            DriverRequestListScreen(),
            DriverProfileDashboard(),
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
