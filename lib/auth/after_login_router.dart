import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tarumt_carpool/services/notifications/fcm_service.dart';
import 'package:tarumt_carpool/repositories/user_repository.dart';
import 'package:tarumt_carpool/models/app_user.dart';
import 'package:tarumt_carpool/screens/Admin/admin_tab_scaffold.dart';
import 'package:tarumt_carpool/screens/Driver/drider_tab_scaffold.dart';
import 'package:tarumt_carpool/screens/Rider/rider_tab_scaffold.dart';
import 'login_screen.dart';
import 'admin_guard.dart';

const String kProfileMissingTitle = 'Account setup incomplete';
const String kProfileMissingMessage =
    'Your account is authenticated, but your profile is missing.\n\n'
    'Please contact the system administrator.';

class AfterLoginRouter extends StatelessWidget {
  AfterLoginRouter({super.key});

  final _auth = FirebaseAuth.instance;
  final _users = UserRepository();

  // ✅ Ensure /users/{uid} exists (so Web never shows "missing profile")
  Future<void> _ensureUserDocExists(User u) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'uid': u.uid,
        'email': u.email,
        'name': u.displayName ?? '',
        'activeRole': 'rider', // default role
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<Widget> _route() async {
    final user = _auth.currentUser;
    if (user == null) return const LoginScreen();



    try {
      // 1) Ensure profile doc exists
      await _ensureUserDocExists(user);

      // 2) Now use your repository
      final AppUser? me = await _users.getCurrentUser();

      if (me == null) {
        return const _FallbackScreen(
          title: kProfileMissingTitle,
          message:
          '$kProfileMissingMessage\n\n(Reason: user doc exists check passed, but repository returned null.)',
        );
      }

      // ✅ Save FCM token only on mobile (Web can require extra setup)
      if (!kIsWeb) {
        await FcmService().initAndSaveToken();
      }

      // ✅ Use activeRole ONLY
      final ar = me.activeRole;

      if (ar == 'admin') {
        return AdminGuard(child: const AdminTabScaffold());
      }
      if (ar == 'driver') {
        return const DriverTabScaffold();
      }
      return const RiderTabScaffold();
    } on FirebaseException catch (e) {
      // ✅ show real firestore/auth error
      return _FallbackScreen(
        title: kProfileMissingTitle,
        message: 'Firebase error: ${e.code}\n${e.message ?? e.toString()}',
      );
    } catch (e) {
      return _FallbackScreen(
        title: kProfileMissingTitle,
        message: 'Error: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _route(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.data ?? const LoginScreen();
      },
    );
  }
}

class _FallbackScreen extends StatelessWidget {
  final String title;
  final String message;

  const _FallbackScreen({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color(0xFF1E73FF);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TARUMT Carpooling'),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (_) => false,
                    );
                  }
                },
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
