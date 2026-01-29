import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/driver_verification_profile.dart';

class DriverVerificationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _verifications =>
      _db.collection('driver_verifications');

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  /// staffId is docId (your choice)
  Stream<Map<String, dynamic>?> streamMyVerificationByStaffId(String staffId) {
    return _verifications.doc(staffId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data();
    });
  }

  /// Submit or Reapply:
  /// - Always sets status to pending
  /// - Clears rejectReason/approvedBy/approvedAt so old admin result won't remain
  Future<void> submit({
    required String uid,
    required String staffId,
    required DriverVerificationProfile profile,
  }) async {
    final ref = _verifications.doc(staffId);

    await ref.set({
      ...profile.toMapForSubmit(),

      // 🔐 reference fields
      'uid': uid,
      'staffId': staffId,

      // 🕒 timestamps
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),

      // ✅ IMPORTANT: clear old reject/approval fields on re-submit
      'verification': {
        'status': 'pending',
        'rejectReason': FieldValue.delete(),
        'approvedBy': FieldValue.delete(),
        'approvedAt': FieldValue.delete(),
      },
    }, SetOptions(merge: true));

    // optional: keep users driverStatus synced
    await _users.doc(uid).update({
      'driverStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
