import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RideRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('riderRequests');

  CollectionReference<Map<String, dynamic>> get _rides =>
      _db.collection('rides');

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamRide(String rideId) {
    return _db.collection('rides').doc(rideId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamRideById(String rideId) {
    return _rides.doc(rideId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamDriverActiveRide(
      String driverId) {
    return _db
        .collection('rides')
        .where('driverID', isEqualTo: driverId)
        .where('rideStatus', whereIn: [
      'incoming',
      'arrived_pickup',
      'ongoing',
      'arrived_destination',
    ])
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRiderActiveRide(String riderId) {
    return _rides
        .where('riderID', isEqualTo: riderId)
        .where('rideStatus', whereIn: [
      'incoming',
      'arrived_pickup',
      'ongoing',
      'arrived_destination',
    ])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRiderRideHistory(String riderId) {
    return _rides
        .where('riderID', isEqualTo: riderId)
        .where('rideStatus', whereIn: ['completed', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamDriverRideHistory(
      String driverId) {
    return _db
        .collection('rides')
        .where('driverID', isEqualTo: driverId)
        .where('rideStatus', whereIn: ['completed', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Driver accepts a rider request
  /// - Transaction-safe
  /// - First driver wins
  Future<String> acceptRequest({
    required String requestId,
  }) async {
    final driverId = _auth.currentUser!.uid;

    return _db.runTransaction<String>((tx) async {
      // ✅ BLOCK multi-accept
      final activeRideQ = _db
          .collection('rides')
          .where('driverID', isEqualTo: driverId)
          .where('rideStatus', whereIn: [
        'incoming',
        'arrived_pickup',
        'ongoing',
        'arrived_destination',
      ])
          .limit(1);

      // final activeRideSnap = await tx.get(activeRideQ);
      // if (activeRideSnap.docs.isNotEmpty) {
      //   throw Exception('You already have an active ride.');
      // }

      // ✅ Get request
      final requestRef = _requests.doc(requestId);
      final requestSnap = await tx.get(requestRef);

      if (!requestSnap.exists) {
        throw Exception('Request not found');
      }

      final req = requestSnap.data()!;
      final status = (req['status'] ?? '').toString();

      if (status != 'waiting') {
        throw Exception('Request already accepted or cancelled');
      }

      // ✅ Create ride
      final rideRef = _rides.doc();
      final now = FieldValue.serverTimestamp();

      tx.set(rideRef, {
        'requestID': requestId,
        'offerID': null,
        'driverID': driverId,
        'riderID': req['riderId'],
        'rideStatus': 'incoming',
        'pickupAddress': req['pickupAddress'],
        'destinationAddress': req['destinationAddress'],
        'pickupGeo': req['pickupGeo'],
        'destinationGeo': req['destinationGeo'],
        'acceptedAt': now,
        'createdAt': now,
        'updatedAt': now,
        'finalFare': null,
        'paymentStatus': 'unpaid',
      });

      // ✅ MUST match your Firestore rule
      tx.update(requestRef, {
        'status': 'incoming',
        'driverId': driverId,
        'activeRideId': rideRef.id,
        'acceptedAt': now,
        'updatedAt': now,
      });

      return rideRef.id;
    });
  }
}

extension RideStatusTransitions on RideRepository {
  Future<void> updateRideStatus({
    required String rideId,
    required String nextStatus,
  }) async {
    final driverId = _auth.currentUser!.uid;

    final rideRef = _rides.doc(rideId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(rideRef);

      if (!snap.exists) {
        throw Exception('Ride not found');
      }

      final ride = snap.data()!;
      if (ride['driverID'] != driverId) {
        throw Exception('Not authorized');
      }

      final current = ride['rideStatus'] as String;

      if (!_isValidTransition(current, nextStatus)) {
        throw Exception('Invalid status transition');
      }

      final now = FieldValue.serverTimestamp();

      final updates = <String, dynamic>{
        'rideStatus': nextStatus,
        'updatedAt': now,
      };

      // timestamp hooks
      if (nextStatus == 'arrived_pickup') {
        updates['arrivedPickupAt'] = now;
      } else if (nextStatus == 'ongoing') {
        updates['startedAt'] = now;
      } else if (nextStatus == 'arrived_destination') {
        updates['arrivedDestinationAt'] = now;
      } else if (nextStatus == 'completed') {
        updates['completedAt'] = now;
      }

      tx.update(rideRef, updates);
    });
  }

  bool _isValidTransition(String from, String to) {
    const allowed = {
      'incoming': ['arrived_pickup'],
      'arrived_pickup': ['ongoing'],
      'ongoing': ['arrived_destination'],
      'arrived_destination': ['completed'],
    };

    return allowed[from]?.contains(to) ?? false;
  }
}

extension RideAutoResume on RideRepository {
  Future<String?> getDriverActiveRideIdOnce(String driverId) async {
    final snap = await _db
        .collection('rides')
        .where('driverID', isEqualTo: driverId)
        .where('rideStatus', whereIn: [
      'incoming',
      'arrived_pickup',
      'ongoing',
      'arrived_destination',
    ])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Future<String?> getRiderActiveRideIdOnce(String riderId) async {
    final snap = await _db
        .collection('rides')
        .where('riderID', isEqualTo: riderId)
        .where('rideStatus', whereIn: [
      'incoming',
      'arrived_pickup',
      'ongoing',
      'arrived_destination',
    ])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }
}

