import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RiderRequestRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('riderRequests');

  /// Create RiderRequest based on your ERD.
  Future<String> createRiderRequest({
    required String origin,
    required String destination,
    required String rideDate, // "YYYY-MM-DD"
    required String rideTime, // "HH:mm"
    required int seatRequested,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in.');

    final doc = _requests.doc(); // auto requestID
    final requestID = doc.id;

    await doc.set({
      'requestID': requestID,
      'origin': origin.trim(),
      'destination': destination.trim(),
      'rideDate': rideDate.trim(),
      'rideTime': rideTime.trim(),
      'seatRequested': seatRequested,
      'requestStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'riderId': user.uid,
    });

    return requestID;
  }
}
