// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../models/app_user.dart';
//
// class UserRepository {
//   final FirebaseFirestore _db = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
//
//   // =========================
//   // REGISTER: DUPLICATE CHECK
//   // =========================
//   Future<List<String>> checkDuplicates({
//     required String userId,
//     required String phone,
//     required String emailLower,
//   }) async {
//     final errors = <String>[];
//
//     final userIdTrim = userId.trim();
//     final phoneTrim = phone.trim();
//     final emailTrim = emailLower.trim();
//
//     final staffDup = await _users.where('userId', isEqualTo: userIdTrim).limit(1).get();
//     if (staffDup.docs.isNotEmpty) errors.add('Student/Staff ID already registered.');
//
//     if (phoneTrim.isNotEmpty) {
//       final phoneDup = await _users.where('phone', isEqualTo: phoneTrim).limit(1).get();
//       if (phoneDup.docs.isNotEmpty) errors.add('Phone number already registered.');
//     }
//
//     final emailDup = await _users.where('email', isEqualTo: emailTrim).limit(1).get();
//     if (emailDup.docs.isNotEmpty) errors.add('Email already registered.');
//
//     return errors;
//   }
//
//   // =========================
//   // REGISTER: CREATE USER
//   // =========================
//   Future<void> createUser(AppUser user) async {
//     final uid = user.uid;
//
//     final ref = _users.doc(uid);
//     final snap = await ref.get();
//     if (snap.exists) throw Exception('User already exists.');
//
//     await ref.set({
//       ...user.toMap(),
//       'createdAt': FieldValue.serverTimestamp(),
//       'updatedAt': FieldValue.serverTimestamp(),
//     });
//   }
//
//   // =========================
//   // READ
//   // =========================
//   Future<AppUser?> getCurrentUser() async {
//     final uid = _auth.currentUser?.uid;
//     if (uid == null) return null;
//
//     final doc = await _users.doc(uid).get();
//     if (!doc.exists) return null;
//
//     return AppUser.fromMap(doc.data()!);
//   }
//
//   Stream<Map<String, dynamic>?> streamUserDoc(String uid) {
//     return _users.doc(uid).snapshots().map((doc) => doc.data());
//   }
//
//   // ✅ NEW: read raw user doc map (sometimes simpler than AppUser)
//   Future<Map<String, dynamic>?> getUserDocMap(String uid) async {
//     final doc = await _users.doc(uid).get();
//     if (!doc.exists) return null;
//     return doc.data();
//   }
//
//   // ✅ NEW: get userId of current logged-in user
//   Future<String?> getuserIdOfCurrentUser() async {
//     final uid = _auth.currentUser?.uid;
//     if (uid == null) return null;
//
//     final doc = await _users.doc(uid).get();
//     if (!doc.exists) return null;
//
//     final data = doc.data();
//     final userId = (data?['userId'] ?? '').toString().trim();
//     if (userId.isEmpty) return null;
//
//     return userId;
//   }
//
//   // =========================
//   // PROFILE: PHONE UPDATE
//   // =========================
//   Future<void> updatePhone({
//     required String uid,
//     required String newPhone,
//   }) async {
//     final phoneTrim = newPhone.trim();
//     if (phoneTrim.isEmpty) throw Exception('Please enter your phone number.');
//
//     final q = await _users.where('phone', isEqualTo: phoneTrim).limit(1).get();
//     if (q.docs.isNotEmpty && q.docs.first.id != uid) {
//       throw Exception('Phone number already registered.');
//     }
//
//     await _users.doc(uid).update({
//       'phone': phoneTrim,
//       'updatedAt': FieldValue.serverTimestamp(),
//     });
//   }
//
//   Future<void> updatePhotoUrl({
//     required String uid,
//     required String photoUrl,
//   }) async {
//     await _users.doc(uid).update({
//       'photoUrl': photoUrl,
//       'updatedAt': FieldValue.serverTimestamp(),
//     });
//   }
//
//   // =========================
//   // ✅ ROLE METHODS
//   // =========================
//   Future<void> setActiveRole({
//     required String uid,
//     required String activeRole, // 'rider' | 'driver' | 'admin'
//   }) async {
//     await _users.doc(uid).update({
//       'activeRole': activeRole,
//       'updatedAt': FieldValue.serverTimestamp(),
//     });
//   }
//
//   Future<void> addRoleIfMissing({
//     required String uid,
//     required String role, // 'rider' | 'driver'
//   }) async {
//     await _users.doc(uid).update({
//       'roles': FieldValue.arrayUnion([role]),
//       'updatedAt': FieldValue.serverTimestamp(),
//     });
//   }
//
//   Future<void> updateUser({
//     required String uid,
//     required Map<String, dynamic> data,
//   }) async {
//     await _users.doc(uid).update({
//       ...data,
//       'updatedAt': FieldValue.serverTimestamp(),
//     });
//   }
// }
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
    required String userId,
    required String phone,
    required String emailLower,
  }) async {
    final errors = <String>[];

    final userIdTrim = userId.trim();
    final phoneTrim = phone.trim();
    final emailTrim = emailLower.trim();

    final staffDup = await _users.where('userId', isEqualTo: userIdTrim).limit(1).get();
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

  /// Optional convenience stream (typed user)
  Stream<AppUser?> streamCurrentUser() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _users.doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return AppUser.fromMap(data);
    });
  }

  Stream<Map<String, dynamic>?> streamUserDoc(String uid) {
    return _users.doc(uid).snapshots().map((doc) => doc.data());
  }

  // read raw user doc map
  Future<Map<String, dynamic>?> getUserDocMap(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  // get userId of current logged-in user
  Future<String?> getuserIdOfCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data();
    final userId = (data?['userId'] ?? '').toString().trim();
    if (userId.isEmpty) return null;

    return userId;
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
  // ROLE METHODS
  // =========================
  Future<void> setActiveRole({
    required String uid,
    required String activeRole,
  }) async {
    await _users.doc(uid).update({
      'activeRole': activeRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addRoleIfMissing({
    required String uid,
    required String role,
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

  // =========================
  // ✅ WALLET HELPERS (CENTS)
  // =========================

  int getWalletBalanceCentsFromMap(Map<String, dynamic> data) {
    return (data['walletBalance'] ?? 0) as int;
  }


  /// Set wallet balance to absolute cents value
  Future<void> updateWalletBalanceCents({
    required String uid,
    required int newBalanceCents,
  }) async {
    if (newBalanceCents < 0) throw Exception('Wallet balance cannot be negative');

    await _users.doc(uid).update({
      'walletBalance': newBalanceCents, // cents
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add cents (for top up credit). This is client-side helper.
  /// If you use Cloud Functions for Stripe confirm, you may not need this.
  Future<void> creditWalletCents({
    required String uid,
    required int amountCents,
  }) async {
    if (amountCents <= 0) throw Exception('Invalid credit amount');

    await _db.runTransaction((tx) async {
      final ref = _users.doc(uid);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('User not found');

      final data = snap.data() as Map<String, dynamic>;
      final bal = getWalletBalanceCentsFromMap(data);

      tx.update(ref, {
        'walletBalance': bal + amountCents,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Deduct cents with RM10 rule:
  /// - balance must be > RM10
  /// - remaining must be >= RM10
  Future<void> deductWalletCentsWithMinRemain({
    required String uid,
    required int amountCents,
    int minRemainCents = 2000, // ✅ RM20
  }) async {
    if (amountCents <= 0) throw Exception('Invalid deduct amount');

    await _db.runTransaction((tx) async {
      final ref = _users.doc(uid);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('User not found');

      final data = snap.data() as Map<String, dynamic>;
      final bal = getWalletBalanceCentsFromMap(data);

      if (bal <= minRemainCents) {
        throw Exception('Balance must be more than RM20.00 to withdraw');
      }
      if (bal - amountCents < minRemainCents) {
        throw Exception('You must keep at least RM20.00 in wallet');
      }

      tx.update(ref, {
        'walletBalance': bal - amountCents,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

}
