import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tarumt_carpool/screens/Rider/rider_tab_scaffold.dart';

import '../repositories/user_repository.dart';
import '../models/app_user.dart';

import '../screens/Admin/admin_home_page.dart';
import '../screens/Driver/driver_home_page.dart';
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

  Future<Widget> _route() async {
    final user = _auth.currentUser; //If nobody is logged in → show login screen
    if (user == null) return const LoginScreen(); //If nobody is logged in → show login screen.

    try {
      // Reads Firestore profile for the current user, returns AppUser or null.
      final AppUser? me = await _users.getCurrentUser();

      // Profile missing in Firestore
      if (me == null) {
        return const _FallbackScreen(
          title: kProfileMissingTitle,
          message: kProfileMissingMessage,
        );
      }

      // ✅ Role-based routing (ALL roles inside users collection)
      if (me.role == 'admin') {
        return AdminGuard(child: const AdminHomePage());
      }

      if (me.role == 'driver') return const DriverHomePage();

      // default rider
      return const RiderTabScaffold();
    } catch (_) {
      return const _FallbackScreen(
        title: kProfileMissingTitle,
        message: kProfileMissingMessage,
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

        // 👈 SAME fallback again (safety)
        if (snap.hasError) {
          return const _FallbackScreen(
            title: kProfileMissingTitle,
            message: kProfileMissingMessage,
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
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
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
