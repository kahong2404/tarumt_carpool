import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDriverVerificationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _verifications =>
      _db.collection('driver_verifications');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Stream list of applications with filters
  ///
  /// status: 'all' | 'pending' | 'approved' | 'rejected'
  /// newestFirst: true = newest first, false = oldest first
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamApplications({
    required String status,
    required bool newestFirst,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query<Map<String, dynamic>> q = _verifications;

    // status filter (skip if 'all')
    if (status != 'all') {
      q = q.where('verification.status', isEqualTo: status);
    }

    // date range filter (optional)
    if (startDate != null) {
      q = q.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      q = q.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    // sort
    q = q.orderBy('createdAt', descending: newestFirst);

    return q.snapshots().map((snap) => snap.docs);
  }

  /// Approve
  Future<void> approve({
    required String staffId,
    required String targetUid,
    required String adminUid,
  }) async {
    final ref = _verifications.doc(staffId);

    await ref.set({
      'verification': {
        'status': 'approved',
        'rejectReason': null,
        'approvedBy': adminUid,
        'approvedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _users.doc(targetUid).update({
      'driverStatus': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject
  Future<void> reject({
    required String staffId,
    required String targetUid,
    required String adminUid,
    required String reason,
  }) async {
    final ref = _verifications.doc(staffId);

    await ref.set({
      'verification': {
        'status': 'rejected',
        'rejectReason': reason.trim(),
        'approvedBy': adminUid, // keep who handled it (optional)
        'approvedAt': FieldValue.serverTimestamp(), // time of decision
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _users.doc(targetUid).update({
      'driverStatus': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
