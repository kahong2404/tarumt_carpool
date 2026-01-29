import 'package:cloud_firestore/cloud_firestore.dart';

class DriverVerificationReviewRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _verifications =>
      _db.collection('driver_verifications');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ---- RAW list stream ----
  Stream<QuerySnapshot<Map<String, dynamic>>> streamListRaw({
    required String status,      // pending/approved/rejected/all
    required bool descending,    // true = latest first
  }) {
    Query<Map<String, dynamic>> q = _verifications;

    if (status != 'all') {
      q = q.where('verification.status', isEqualTo: status);
    }

    // ✅ server sort
    q = q.orderBy('createdAt', descending: descending);

    return q.snapshots();
  }

  // ---- single doc stream ----
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamByStaffIdRaw(String staffId) {
    return _verifications.doc(staffId).snapshots();
  }

  // ---- review action ----
  Future<void> reviewApplicationRaw({
    required String staffId,
    required String decision,     // approved | rejected
    required String reviewerUid,  // admin uid
    String? rejectReason,
  }) async {
    final vRef = _verifications.doc(staffId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(vRef);
      if (!snap.exists) throw Exception('Application not found.');

      final data = snap.data()!;
      final uid = (data['uid'] ?? '').toString();
      if (uid.isEmpty) throw Exception('Missing uid in verification doc.');

      if (decision == 'rejected') {
        final reason = (rejectReason ?? '').trim();
        if (reason.isEmpty) throw Exception('Reject reason is required.');
      }

      tx.update(vRef, {
        'verification.status': decision,
        'verification.reviewedBy': reviewerUid,
        'verification.reviewedAt': FieldValue.serverTimestamp(),

        if (decision == 'approved') ...{
          'verification.rejectReason': FieldValue.delete(),
          'verification.approvedBy': reviewerUid,
          'verification.approvedAt': FieldValue.serverTimestamp(),
        },

        if (decision == 'rejected') ...{
          'verification.rejectReason': rejectReason!.trim(),
          'verification.approvedBy': FieldValue.delete(),
          'verification.approvedAt': FieldValue.delete(),
        },

        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ this needs USERS rules for admin (we allowed only driverStatus + updatedAt)
      tx.update(_users.doc(uid), {
        'driverStatus': decision,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
