import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../utils/validators.dart';

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> ensureEmailNotUsed(String email) async {
    final emailLower = email.trim().toLowerCase();
    final q = await _db
        .collection('users')
        .where('email', isEqualTo: emailLower)
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) {
      throw Exception('Email already registered');
    }
  }

  Future<void> createUser(AppUser user) async {
    final staffId = user.staffId.trim();
    final phoneKey = Validators.normalizeMalaysiaPhone(user.phone);

    final userDoc = _db.collection('users').doc(staffId);
    final phoneDoc = _db.collection('phones').doc(phoneKey);
    final uidMapDoc = _db.collection('user_uid_map').doc(user.uid);

    final staffSnap = await userDoc.get();
    if (staffSnap.exists) throw Exception('Student/Staff ID already exists.');

    final phoneSnap = await phoneDoc.get();
    if (phoneSnap.exists) throw Exception('Phone number already exists.');

    await ensureEmailNotUsed(user.email);

    final batch = _db.batch();

    batch.set(userDoc, {
      ...user.toMap(),
      'phoneKey': phoneKey,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(phoneDoc, {
      'staffId': staffId,
      'uid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(uidMapDoc, {
      'staffId': staffId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<AppUser> getUserByStaffId(String staffId) async {
    final doc = await _db.collection('users').doc(staffId).get();
    if (!doc.exists) throw Exception('User record not found.');
    return AppUser.fromMap(doc.data()!);
  }

  Future<AppUser> getUserByUid(String uid) async {
    final mapDoc = await _db.collection('user_uid_map').doc(uid).get();
    if (!mapDoc.exists) throw Exception('User mapping not found.');

    final staffId = mapDoc.data()!['staffId'] as String;
    return getUserByStaffId(staffId);
  }

  /// ✅ ADD THIS BACK (so DriverHomePage can call it)
  Future<AppUser?> getCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return getUserByUid(uid);
  }
}
