import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../notifications/notification_list_page.dart';
import '../../reviews/driver_my_reviews_screen.dart';

import '../../../auth/after_login_router.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/profile_service.dart';
import '../../../widgets/profile/profile_header.dart';
import '../../../widgets/profile/profile_action_button.dart';
import '../profile_detail_screen.dart';
import '../../driver_verification/driver/driver_verification_center_page.dart';

// ✅ adjust this import if your path is different
import '../../driver_verification/driver/driver_verification_form_page.dart';

class DriverProfileDashboard extends StatelessWidget {
  DriverProfileDashboard({super.key});

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

          final roles = List<String>.from(d['roles'] ?? ['driver']);
          final activeRole = (d['activeRole'] ?? 'driver').toString();

          final hasRider = roles.contains('rider');
          final hasDriver = roles.contains('driver');

          Widget roleButton() {
            // Driver only -> Become rider
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

            // Rider+Driver & currently driver -> switch to rider
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

            // If user is rider only but opened driver dashboard (rare)
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

            // Rider+Driver & currently rider (rare in driver dashboard)
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

            return const SizedBox.shrink();
          }

          // ✅ IMPORTANT: call roleButton() ONCE
          final rb = roleButton();

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
                    rb,
                    if (rb is! SizedBox) const SizedBox(height: 10),

                    ProfileActionButton(
                      label: 'Driver Verification Center',
                      icon: Icons.verified_user_outlined,
                      onTap: () {
                        final staffId = (d['staffId'] ?? '').toString();

                        if (staffId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Staff ID not found.')),
                          );
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>  DriverVerificationCenterPage(
                            ),
                          ),
                        );
                      },
                    ),


                    ProfileActionButton(
                      label: 'Earnings',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () {},
                    ),
                    ProfileActionButton(
                      label: 'My Vehicles',
                      icon: Icons.directions_car_outlined,
                      onTap: () {},
                    ),
                    ProfileActionButton(
                      label: 'My Reviews',
                      icon: Icons.star_border_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => DriverMyReviewsScreen()),
                        );
                      },
                    ),
                    ProfileActionButton(
                      label: 'Notifications',
                      icon: Icons.notifications_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => NotificationListPage()),
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
