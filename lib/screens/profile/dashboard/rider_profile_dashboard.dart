import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../payment/wallet_screen.dart';

import '../../../auth/after_login_router.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/profile_service.dart';
import '../../../widgets/profile/profile_header.dart';
import '../../../widgets/profile/profile_action_button.dart';
import '../profile_detail_screen.dart';

class RiderProfileDashboard extends StatelessWidget {
  RiderProfileDashboard({super.key});

  final _auth = FirebaseAuth.instance;
  final _repo = UserRepository();
  final _svc = ProfileService();

  static const bg = Color(0xFFF5F6FA);

  void _goHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => AfterLoginRouter()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: bg,
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _repo.streamUserDoc(uid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final d = snap.data!;
          final name = (d['name'] ?? '') as String;
          final photoUrl = (d['photoUrl'] ?? '') as String;

          final roles = List<String>.from(d['roles'] ?? ['rider']);
          final activeRole = (d['activeRole'] ?? 'rider').toString();

          final hasRider = roles.contains('rider');
          final hasDriver = roles.contains('driver');

          Widget roleButton() {
            // Rider only -> Become driver
            if (hasRider && !hasDriver) {
              return ProfileActionButton(
                label: 'Become a Driver',
                icon: Icons.drive_eta_outlined,
                onTap: () async {
                  await _svc.becomeDriver();
                  if (!context.mounted) return;
                  _goHome(context);
                },
              );
            }

            // Rider+Driver & currently rider -> switch to driver
            if (hasRider && hasDriver && activeRole == 'rider') {
              return ProfileActionButton(
                label: 'Switch to Driver Mode',
                icon: Icons.swap_horiz,
                onTap: () async {
                  await _svc.switchToDriver();
                  if (!context.mounted) return;
                  _goHome(context);
                },
              );
            }

            // If user is driver only but opened rider dashboard (rare)
            if (hasDriver && !hasRider) {
              return ProfileActionButton(
                label: 'Become a Rider',
                icon: Icons.person_outline,
                onTap: () async {
                  await _svc.becomeRider();
                  if (!context.mounted) return;
                  _goHome(context);
                },
              );
            }

            // Rider+Driver & currently driver (rare in rider dashboard)
            if (hasRider && hasDriver && activeRole == 'driver') {
              return ProfileActionButton(
                label: 'Switch to Rider Mode',
                icon: Icons.swap_horiz,
                onTap: () async {
                  await _svc.switchToRider();
                  if (!context.mounted) return;
                  _goHome(context);
                },
              );
            }

            return const SizedBox.shrink();
          }

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
                    roleButton(),
                    if (roleButton() is! SizedBox) const SizedBox(height: 10),

                    ProfileActionButton(
                      label: 'Review',
                      icon: Icons.rate_review_outlined,
                      onTap: () {},
                    ),
                    ProfileActionButton(
                      label: 'Payment',
                      icon: Icons.payment_outlined,
                      onTap: () {},
                    ),
                    ProfileActionButton(
                      label: 'Payment',
                      icon: Icons.star_border,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const WalletScreen()),
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
