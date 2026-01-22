import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/driver_verification_profile.dart';

class DriverVerificationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _verifications =>
      _db.collection('driver_verifications');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Use staffId as docId (your choice)
  Stream<Map<String, dynamic>?> streamMyVerificationByStaffId(String staffId) {
    return _verifications.doc(staffId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data();
    });
  }

  Future<void> submit({
    required String uid,
    required String staffId,
    required DriverVerificationProfile profile,
  }) async {
    final ref = _verifications.doc(staffId);

    await ref.set({
      ...profile.toMapForSubmit(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // keep a reference to uid too (helpful for admin)
      'uid': uid,
      'staffId': staffId,
    }, SetOptions(merge: true));

    // optional: keep users driverStatus synced
    await _users.doc(uid).update({
      'driverStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
