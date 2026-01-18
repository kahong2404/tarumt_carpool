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

  Future<void> createUser(AppUser user) async {
    final uid = user.uid;

    // ✅ Prevent overwriting same UID (safety check)
    final existing = await _users.doc(uid).get();
    if (existing.exists) {
      throw Exception('User already exists.');
    }

    // ✅ Just write data (duplicates already checked earlier)
    await _users.doc(uid).set({
      ...user.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  Future<List<String>> checkDuplicates({
    required String staffId,
    required String phone,
    required String emailLower,
  }) async {
    final errors = <String>[];

    final staffDup =
    await _users.where('staffId', isEqualTo: staffId).limit(1).get();
    if (staffDup.docs.isNotEmpty) {
      errors.add('Student/Staff ID already registered.');
    }

    final phoneDup =
    await _users.where('phone', isEqualTo: phone).limit(1).get();
    if (phoneDup.docs.isNotEmpty) {
      errors.add('Phone number already registered.');
    }

    final emailDup =
    await _users.where('email', isEqualTo: emailLower).limit(1).get();
    if (emailDup.docs.isNotEmpty) {
      errors.add('Email already registered.');
    }

    return errors;
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
