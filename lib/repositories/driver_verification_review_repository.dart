import 'package:cloud_firestore/cloud_firestore.dart';

class DriverVerificationReviewRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _verifications =>
      _db.collection('driver_verifications');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamListRaw({
    required String status,
    required bool descending,
  }) {
    Query<Map<String, dynamic>> q = _verifications;

    if (status != 'all') {
      q = q.where('verification.status', isEqualTo: status);
    }

    q = q.orderBy('updatedAt', descending: descending);
    return q.snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamByuserIdRaw(String userId) {
    return _verifications.doc(userId.trim()).snapshots();
  }

  Future<void> reviewApplicationRaw({
    required String userId,
    required String decision, // approved | rejected
    required String reviewerUid,
    String? rejectReason,
  }) async {
    final userIdTrim = userId.trim();
    if (userIdTrim.isEmpty) throw Exception('Missing userId.');

    final vRef = _verifications.doc(userIdTrim);

    await _db.runTransaction((tx) async {
      final vSnap = await tx.get(vRef);
      if (!vSnap.exists) throw Exception('Application not found.');

      final data = vSnap.data() ?? {};
      final uid = (data['uid'] ?? '').toString().trim();
      if (uid.isEmpty) throw Exception('Missing uid in verification doc.');

      final now = FieldValue.serverTimestamp();

      if (decision == 'approved') {
        tx.update(vRef, {
          'verification.status': 'approved',
          'verification.approvedBy': reviewerUid,
          'verification.approvedAt': now,

          // clear reject fields
          'verification.rejectReason': FieldValue.delete(),
          'verification.reviewedBy': FieldValue.delete(),
          'verification.reviewedAt': FieldValue.delete(),

          'updatedAt': now,
        });

        // sync user
        tx.update(_users.doc(uid), {
          'driverStatus': 'approved',
          'updatedAt': now,
        });

        return;
      }

      if (decision == 'rejected') {
        final r = (rejectReason ?? '').trim();
        if (r.isEmpty) throw Exception('Reject reason required.');

        tx.update(vRef, {
          'verification.status': 'rejected',

          // ✅ current reject reason (for rejected state)
          'verification.rejectReason': r,

          // ✅ IMPORTANT: keep latest reject reason forever
          'verification.lastRejectReason': r,

          'verification.reviewedBy': reviewerUid,
          'verification.reviewedAt': now,

          // clear approve fields
          'verification.approvedBy': FieldValue.delete(),
          'verification.approvedAt': FieldValue.delete(),

          'updatedAt': now,
        });

        // sync user
        tx.update(_users.doc(uid), {
          'driverStatus': 'rejected',
          'updatedAt': now,
        });

        return;
      }

      throw Exception('Unknown decision: $decision');
    });
  }
}
