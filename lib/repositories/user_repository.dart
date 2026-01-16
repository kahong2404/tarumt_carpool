import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ Single collection only
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // Optional helper (normalized email uniqueness)
  Future<void> ensureEmailNotUsed(String email) async {
    final emailLower = email.trim().toLowerCase();
    final q = await _users.where('email', isEqualTo: emailLower).limit(1).get();

    if (q.docs.isNotEmpty) {
      throw Exception('Email already registered.');
    }
  }

  // ✅ Create user profile under users/{uid}
  Future<void> createUser(AppUser user) async {
    final uid = user.uid;
    final staffId = user.staffId.trim();
    final emailLower = user.email.trim().toLowerCase();
    final phone = user.phone.trim();

    // 1) Prevent overwriting same UID
    final existing = await _users.doc(uid).get();
    if (existing.exists) {
      throw Exception('User already exists.');
    }

    // 2) Uniqueness checks inside the SAME users collection
    // (Not 100% race-safe, but OK for FYP / small traffic)
    final staffDup =
    await _users.where('staffId', isEqualTo: staffId).limit(1).get();
    if (staffDup.docs.isNotEmpty) {
      throw Exception('Student/Staff ID already registered.');
    }

    final phoneDup =
    await _users.where('phone', isEqualTo: phone).limit(1).get();
    if (phoneDup.docs.isNotEmpty) {
      throw Exception('Phone number already registered.');
    }

    await ensureEmailNotUsed(emailLower);

    // save yo the firestore at users/{uid}
    await _users.doc(uid).set({
      ...user.toMap(),
      'email': emailLower,
      'staffId': staffId,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ✅ Get currently logged-in user's profile (users/{uid})
  Future<AppUser?> getCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;

    return AppUser.fromMap(doc.data()!);
  }

  // ✅ Get any user by uid
  Future<AppUser> getUserByUid(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) throw Exception('User record not found.');
    return AppUser.fromMap(doc.data()!);
  }

  // ✅ Optional: find user by staffId (query)
  Future<AppUser> getUserByStaffId(String staffId) async {
    final q = await _users
        .where('staffId', isEqualTo: staffId.trim())
        .limit(1)
        .get();

    if (q.docs.isEmpty) throw Exception('User record not found.');
    return AppUser.fromMap(q.docs.first.data());
  }

  // ✅ Optional: update timestamps helper
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
