import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

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

    final staffDup = await _users.where('staffId', isEqualTo: staffIdTrim).limit(1).get();
    if (staffDup.docs.isNotEmpty) errors.add('Student/Staff ID already registered.');

    if (phoneTrim.isNotEmpty) {
      final phoneDup = await _users.where('phone', isEqualTo: phoneTrim).limit(1).get();
      if (phoneDup.docs.isNotEmpty) errors.add('Phone number already registered.');
    }

    final emailDup = await _users.where('email', isEqualTo: emailTrim).limit(1).get();
    if (emailDup.docs.isNotEmpty) errors.add('Email already registered.');

    return errors;
  }

  // =========================
  // REGISTER: CREATE USER
  // =========================
  Future<void> createUser(AppUser user) async {
    final uid = user.uid;

    final ref = _users.doc(uid);
    final snap = await ref.get();
    if (snap.exists) throw Exception('User already exists.');

    await ref.set({
      ...user.toMap(),
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

  Stream<Map<String, dynamic>?> streamUserDoc(String uid) {
    return _users.doc(uid).snapshots().map((doc) => doc.data());
  }

  // ✅ NEW: read raw user doc map (sometimes simpler than AppUser)
  Future<Map<String, dynamic>?> getUserDocMap(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  // ✅ NEW: get staffId of current logged-in user
  Future<String?> getStaffIdOfCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data();
    final staffId = (data?['staffId'] ?? '').toString().trim();
    if (staffId.isEmpty) return null;

    return staffId;
  }

  // =========================
  // PROFILE: PHONE UPDATE
  // =========================
  Future<void> updatePhone({
    required String uid,
    required String newPhone,
  }) async {
    final phoneTrim = newPhone.trim();
    if (phoneTrim.isEmpty) throw Exception('Please enter your phone number.');

    final q = await _users.where('phone', isEqualTo: phoneTrim).limit(1).get();
    if (q.docs.isNotEmpty && q.docs.first.id != uid) {
      throw Exception('Phone number already registered.');
    }

    await _users.doc(uid).update({
      'phone': phoneTrim,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

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
  // ✅ ROLE METHODS
  // =========================
  Future<void> setActiveRole({
    required String uid,
    required String activeRole, // 'rider' | 'driver' | 'admin'
  }) async {
    await _users.doc(uid).update({
      'activeRole': activeRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addRoleIfMissing({
    required String uid,
    required String role, // 'rider' | 'driver'
  }) async {
    await _users.doc(uid).update({
      'roles': FieldValue.arrayUnion([role]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUser({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _users.doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
