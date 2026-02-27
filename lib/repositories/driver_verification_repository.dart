import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarumt_carpool/models/driver_verification_profile.dart';

class DriverVerificationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _verifications =>
      _db.collection('driver_verifications');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Stream<Map<String, dynamic>?> streamByuserId(String userId) {
    return _verifications.doc(userId.trim()).snapshots().map((d) => d.data());
  }

  Future<Map<String, dynamic>?> getByuserId(String userId) async {
    final doc = await _verifications.doc(userId.trim()).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<void> submitPending({
    required String uid,
    required String userId,
    required DriverVerificationProfile profile,
  }) async {
    final userIdTrim = userId.trim();
    if (userIdTrim.isEmpty) throw Exception('Missing userId.');

    final vRef = _verifications.doc(userIdTrim);
    final uRef = _users.doc(uid);

    await _db.runTransaction((tx) async {
      final vSnap = await tx.get(vRef);

      // ✅ preserve latest reject reason (prefer lastRejectReason, fallback to rejectReason)
      String? latestReason;
      if (vSnap.exists) {
        final old = vSnap.data() ?? {};
        final ver = Map<String, dynamic>.from(old['verification'] ?? {});
        final last = (ver['lastRejectReason'] ?? '').toString().trim();
        final cur = (ver['rejectReason'] ?? '').toString().trim();

        if (last.isNotEmpty) {
          latestReason = last;
        } else if (cur.isNotEmpty) {
          latestReason = cur;
        }
      }

      tx.set(
        vRef,
        {
          'uid': uid,
          'userId': userIdTrim,
          if (!vSnap.exists) 'submittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),

          ...profile.toMapForSubmitPending(),

        },
        SetOptions(merge: true),
      );

      tx.update(uRef, {
        'driverStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
