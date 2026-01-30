import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RiderRequestRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('riderRequests');

  Future<String> createRiderRequest({
    required String pickupAddress,
    required String destinationAddress,
    required GeoPoint pickupGeo,
    required GeoPoint destinationGeo,
    required String rideDate,
    required String rideTime,
    required int seatRequested,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final doc = _requests.doc();
    final requestId = doc.id;

    await doc.set({
      'requestId': requestId,

      // standardized fields
      'pickupAddress': pickupAddress.trim(),
      'destinationAddress': destinationAddress.trim(),
      'pickupGeo': pickupGeo,
      'destinationGeo': destinationGeo,

      'rideDate': rideDate,
      'rideTime': rideTime,
      'seatRequested': seatRequested,

      // 🔒 locked status model
      'status': 'waiting',
      'activeRideId': null,

      'riderId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return requestId;
  }


  Stream<DocumentSnapshot<Map<String, dynamic>>> streamRequest(String requestId) {
    return _requests.doc(requestId).snapshots();
  }

  /// Rider cancels ONLY while waiting
  Future<void> cancelRequestWhileWaiting(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final ref = _requests.doc(requestId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Request not found');

      final d = snap.data()!;
      if (d['riderId'] != user.uid) throw Exception('Not your request');

      final status = (d['status'] ?? '').toString();
      if (status != 'waiting') {
        throw Exception('Cannot cancel after driver accepted');
      }

      tx.update(ref, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
