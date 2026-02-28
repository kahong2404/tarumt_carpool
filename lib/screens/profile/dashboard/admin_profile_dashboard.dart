import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tarumt_carpool/screens/driver_verification/admin/driver_verification_list_page.dart';
import 'package:tarumt_carpool/screens/reviews/admin/review_list_screen.dart';
import 'package:tarumt_carpool/screens/profile/profile_detail_screen.dart';
import 'package:tarumt_carpool/repositories/user_repository.dart';
import 'package:tarumt_carpool/widgets/profile/profile_header.dart';
import 'package:tarumt_carpool/widgets/profile/profile_action_button.dart';

class AdminProfileDashboard extends StatelessWidget {
   AdminProfileDashboard({super.key});

  final _auth = FirebaseAuth.instance;
  final _repo = UserRepository();

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _repo.streamUserDoc(uid),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final d = snap.data!;
          final name = (d['name'] ?? '') as String;
          final photoUrl = (d['photoUrl'] ?? '') as String;

          return Column(
            children: [
              ProfileHeader(
                name: name,
                photoUrl: photoUrl.isEmpty ? null : photoUrl,
                onProfileTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileDetailScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // ProfileActionButton(label: 'User Management', icon: Icons.manage_accounts_outlined, onTap: () {}),
                    ProfileActionButton(
                      label: 'Driver Verification',
                      icon: Icons.verified_user_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DriverVerificationListPage(),
                          ),
                        );
                      },
                    ),
                ProfileActionButton(
                  label: 'Driver Reviews',
                  icon: Icons.star_border_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminReviewListScreen()),
                    );
                  },
                ),



                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
