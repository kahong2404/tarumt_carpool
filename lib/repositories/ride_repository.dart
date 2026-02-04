import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ride.dart';

class RideRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const activeStatuses = [
    'incoming',
    'arrived_pickup',
    'ongoing',
    'arrived_destination',
  ];

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('riderRequests');

  CollectionReference<Map<String, dynamic>> get _rides => _db.collection('rides');

  // ----------------------------
  // OOP STREAMS (Recommended)
  // ----------------------------
  Stream<Ride> streamRideModel(String rideId) {
    return _rides.doc(rideId).snapshots().map((doc) => Ride.fromDoc(doc));
  }

  Stream<Ride?> streamDriverActiveRideModel(String driverId) {
    return streamDriverActiveRide(driverId).map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return Ride.fromMap(doc.id, doc.data());
    });
  }

  Stream<Ride?> streamRiderActiveRideModel(String riderId) {
    return streamRiderActiveRide(riderId).map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return Ride.fromMap(doc.id, doc.data());
    });
  }

  // ----------------------------
  // RAW STREAMS (If you still need Map)
  // ----------------------------
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamRide(String rideId) {
    return _rides.doc(rideId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamDriverActiveRide(String driverId) {
    return _rides
        .where('driverID', isEqualTo: driverId)
        .where('rideStatus', whereIn: activeStatuses)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamDriverRideHistory(String driverId) {
    return _rides
        .where('driverID', isEqualTo: driverId)
        .where('rideStatus', whereIn: const ['completed', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRiderActiveRide(String riderId) {
    return _rides
        .where('riderID', isEqualTo: riderId)
        .where('rideStatus', whereIn: activeStatuses)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRiderRideHistory(String riderId) {
    return _rides
        .where('riderID', isEqualTo: riderId)
        .where('rideStatus', whereIn: const ['completed', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();
  }

  // ----------------------------
  // ACCEPT REQUEST (BLOCK MULTI-ACCEPT )
  // ----------------------------
  Future<String> acceptRequest({required String requestId}) async {
    final driverId = _auth.currentUser!.uid;

    // ✅ PRE-CHECK
    final activeRideSnap = await _rides
        .where('driverID', isEqualTo: driverId)
        .where('rideStatus', whereIn: activeStatuses)
        .limit(1)
        .get();

    if (activeRideSnap.docs.isNotEmpty) {
      throw Exception('You already have an active ride.');
    }

    //TRANSACTION (locks request)
    return _db.runTransaction<String>((tx) async {
      final requestRef = _requests.doc(requestId);
      final requestSnap = await tx.get(requestRef);

      if (!requestSnap.exists) throw Exception('Request not found');

      final req = requestSnap.data()!;
      final status = (req['status'] ?? '').toString();

      if (status != 'waiting') {
        throw Exception('Request already accepted or cancelled');
      }

      final rideRef = _rides.doc();
      final now = FieldValue.serverTimestamp();

      tx.set(rideRef, {
        // relations
        'requestID': requestId,
        'offerID': null,
        'driverID': driverId,
        'riderID': req['riderId'], // must be uid string

        // status
        'rideStatus': 'incoming',

        // copied location data
        'pickupAddress': req['pickupAddress'],
        'destinationAddress': req['destinationAddress'],
        'pickupGeo': req['pickupGeo'],
        'destinationGeo': req['destinationGeo'],

        // timestamps
        'acceptedAt': now,
        'createdAt': now,
        'updatedAt': now,

        // payment
        'finalFare': null,
        'paymentStatus': 'unpaid',
      });

      // update request doc
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

// =====================================================
// STATUS TRANSITIONS
// =====================================================
extension RideStatusTransitions on RideRepository {
  Future<void> updateRideStatus({
    required String rideId,
    required String nextStatus, // keep String for now
  }) async {
    final driverId = _auth.currentUser!.uid;
    final rideRef = _db.collection('rides').doc(rideId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(rideRef);
      if (!snap.exists) throw Exception('Ride not found');

      final ride = snap.data() as Map<String, dynamic>;
      if (ride['driverID'] != driverId) throw Exception('Not authorized');

      final current = (ride['rideStatus'] ?? '').toString();

      if (!_isValidTransition(current, nextStatus)) {
        throw Exception('Invalid status transition');
      }

      final now = FieldValue.serverTimestamp();

      final updates = <String, dynamic>{
        'rideStatus': nextStatus,
        'updatedAt': now,
      };

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

// =====================================================
// AUTO RESUME (ONE-TIME LOOKUP)
// =====================================================
extension RideAutoResume on RideRepository {
  Future<String?> getDriverActiveRideIdOnce(String driverId) async {
    final snap = await _db
        .collection('rides')
        .where('driverID', isEqualTo: driverId)
        .where('rideStatus', whereIn: RideRepository.activeStatuses)
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
        .where('rideStatus', whereIn: RideRepository.activeStatuses)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }
}
