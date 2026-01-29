import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminGuard extends StatelessWidget {
  final Widget child;
  const AdminGuard({super.key, required this.child});

  Future<bool> _isAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final doc =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return false;

    final data = doc.data()!;
    return (data['activeRole'] as String?) == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAdmin(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snap.data != true) {
          return const Scaffold(
            body: Center(child: Text('Access denied (Admin only).')),
          );
        }

        return child;
      },
    );
  }
}
