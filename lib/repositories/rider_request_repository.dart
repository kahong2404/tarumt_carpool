import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RiderRequestRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('riderRequests');

  Future<String> createRiderRequest({
    required String originAddress,
    required String destinationAddress,
    required GeoPoint originGeo,
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
      'originAddress': originAddress.trim(),
      'destinationAddress': destinationAddress.trim(),

      // ✅ GeoPoints
      'originGeo': originGeo,
      'destinationGeo': destinationGeo,

      'rideDate': rideDate,
      'rideTime': rideTime,
      'seatRequested': seatRequested,
      'requestStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'riderId': user.uid,
    });

    return requestId;
  }
}
