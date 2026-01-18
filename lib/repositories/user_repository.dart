import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // =========================
  // Collection
  // =========================
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // =========================
  // REGISTER: DUPLICATE CHECK
  // =========================
  Future<List<String>> checkDuplicates({
    required String staffId,
    required String phone,
    required String emailLower,
  }) async {
    final errors = <String>[];

    final staffIdTrim = staffId.trim();
    final phoneTrim = phone.trim();
    final emailTrim = emailLower.trim();

    // staffId duplicate
    final staffDup = await _users
        .where('staffId', isEqualTo: staffIdTrim)
        .limit(1)
        .get();
    if (staffDup.docs.isNotEmpty) {
      errors.add('Student/Staff ID already registered.');
    }

    // phone duplicate
    if (phoneTrim.isNotEmpty) {
      final phoneDup = await _users
          .where('phone', isEqualTo: phoneTrim)
          .limit(1)
          .get();
      if (phoneDup.docs.isNotEmpty) {
        errors.add('Phone number already registered.');
      }
    }

    // email duplicate
    final emailDup = await _users
        .where('email', isEqualTo: emailTrim)
        .limit(1)
        .get();
    if (emailDup.docs.isNotEmpty) {
      errors.add('Email already registered.');
    }

    return errors;
  }

  // =========================
  // REGISTER: CREATE USER
  // =========================
  Future<void> createUser(AppUser user) async {
    final uid = user.uid;

    final ref = _users.doc(uid);
    final snap = await ref.get();
    if (snap.exists) {
      throw Exception('User already exists.');
    }

    await ref.set({
      ...user.toMap(),
      'phone': user.phone.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================
  // READ
  // =========================
  Future<AppUser?> getCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;

    return AppUser.fromMap(doc.data()!);
  }

  Future<AppUser> getUserByUid(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) throw Exception('User record not found.');
    return AppUser.fromMap(doc.data()!);
  }

  // =========================
  // PROFILE: PHONE UPDATE
  // =========================
  Future<void> updatePhone({
    required String uid,
    required String newPhone,
  }) async {
    final phoneTrim = newPhone.trim();
    if (phoneTrim.isEmpty) {
      throw Exception('Please enter your phone number.');
    }

    // 🔴 CHECK DUPLICATE (users collection)
    final q = await _users
        .where('phone', isEqualTo: phoneTrim)
        .limit(1)
        .get();

    if (q.docs.isNotEmpty && q.docs.first.id != uid) {
      throw Exception('Phone number already registered.');
    }

    await _users.doc(uid).update({
      'phone': phoneTrim,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================
  // PROFILE: PHOTO
  // =========================
  Future<void> updatePhotoUrl({
    required String uid,
    required String photoUrl,
  }) async {
    await _users.doc(uid).update({
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================
  // STREAM
  // =========================
  Stream<Map<String, dynamic>?> streamUserDoc(String uid) {
    return _users.doc(uid).snapshots().map((doc) => doc.data());
  }
}
