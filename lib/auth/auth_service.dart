import '../models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isTarumtEmail(String email) {
    final e = email.trim().toLowerCase();
    return e.endsWith('@student.tarc.edu.my') || e.endsWith('@tarc.edu.my');
  }

  Future<void> register({
    required String role,
    required String staffId,
    required String phone,
    required String email,
    required String password,
  }) async {
    if (!_isTarumtEmail(email)) {
      throw Exception('Please use a valid TARUMT email.');
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    final uid = cred.user!.uid;

    final driverStatus = (role == 'driver') ? 'pending' : 'not_driver';

    // ✅ OOP: create AppUser object
    final appUser = AppUser(
      uid: uid,
      email: email.trim().toLowerCase(),
      staffId: staffId.trim(),
      phone: phone.trim(),
      role: role,
      driverStatus: driverStatus,
      walletBalance: 0,
    );

    // ✅ OOP: save object to Firestore
    await _db.collection('users').doc(uid).set({
      ...appUser.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

}

