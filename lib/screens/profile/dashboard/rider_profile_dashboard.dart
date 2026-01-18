import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../repositories/user_repository.dart';
import '../../../widgets/profile/profile_header.dart';
import '../../../widgets/profile/profile_action_button.dart';
import '../profile_detail_screen.dart';

class RiderProfileDashboard extends StatelessWidget {
  RiderProfileDashboard({super.key});

  final _auth = FirebaseAuth.instance;
  final _repo = UserRepository();

  static const bg = Color(0xFFF5F6FA);

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: bg,
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
                    ProfileActionButton(label: 'Review', icon: Icons.rate_review_outlined, onTap: () {}),
                    ProfileActionButton(label: 'Payment', icon: Icons.payment_outlined, onTap: () {}),
                    ProfileActionButton(label: 'Subscriptions', icon: Icons.subscriptions_outlined, onTap: () {}),
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
