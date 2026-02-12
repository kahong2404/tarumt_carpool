import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ride.dart';

class RideRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ ONLY ride statuses here (not request)
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
  // RAW STREAMS
  // ----------------------------
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamRide(String rideId) {
    return _rides.doc(rideId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamDriverActiveRide(
      String driverId) {
    return _rides
        .where('driverID', isEqualTo: driverId)
        .where('rideStatus', whereIn: activeStatuses)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRiderActiveRequest(
      String riderId) {
    return _db
        .collection('riderRequests')
        .where('riderId', isEqualTo: riderId)
        .where('status', whereIn: const ['waiting', 'scheduled', 'incoming'])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamDriverRideHistory(
      String driverId) {
    return _rides
        .where('driverID', isEqualTo: driverId)
        .where('rideStatus', whereIn: const ['completed', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRiderActiveRide(
      String riderId) {
    return _rides
        .where('riderID', isEqualTo: riderId)
        .where('rideStatus', whereIn: activeStatuses)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRiderRideHistory(
      String riderId) {
    return _rides
        .where('riderID', isEqualTo: riderId)
        .where('rideStatus', whereIn: const ['completed', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();
  }

  // ----------------------------
  // ACCEPT REQUEST (BLOCK MULTI-ACCEPT)
  // ----------------------------
  /// Flow:
  /// riderRequests.status: waiting -> incoming
  /// rides.rideStatus: incoming
  Future<String> acceptRequest({required String requestId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final driverId = user.uid;

    // ✅ PRE-CHECK: driver can't accept if already has active ride
    final activeRideSnap = await _rides
        .where('driverID', isEqualTo: driverId)
        .where('rideStatus', whereIn: activeStatuses)
        .limit(1)
        .get();

    if (activeRideSnap.docs.isNotEmpty) {
      throw Exception('You already have an active ride.');
    }

    // ✅ TRANSACTION (locks request)
    return _db.runTransaction<String>((tx) async {
      final requestRef = _requests.doc(requestId);
      final requestSnap = await tx.get(requestRef);

      if (!requestSnap.exists) throw Exception('Request not found');

      final req = requestSnap.data()!;
      final status = (req['status'] ?? '').toString();

      // Only allow accepting if still waiting
      if (status != 'waiting') {
        throw Exception('Request already accepted/cancelled/expired');
      }

      // If some old logic already wrote matchedDriverId, block.
      final existingMatched = req['matchedDriverId'];
      if (existingMatched != null && existingMatched.toString().isNotEmpty) {
        throw Exception('Request already taken by another driver.');
      }

      final riderId = (req['riderId'] ?? '').toString();
      if (riderId.isEmpty) throw Exception('Request missing riderId');

      // copy fields (must exist)
      final pickupAddress = (req['pickupAddress'] ?? '').toString();
      final destinationAddress = (req['destinationAddress'] ?? '').toString();
      final pickupGeo = req['pickupGeo'];
      final destinationGeo = req['destinationGeo'];

      if (pickupGeo is! GeoPoint || destinationGeo is! GeoPoint) {
        throw Exception('Request missing pickup/destination GeoPoint');
      }

      final rideRef = _rides.doc();
      final now = FieldValue.serverTimestamp();

      // 1) create ride
      tx.set(rideRef, {
        // relations
        'requestId': requestId,
        'offerId': null,
        'driverID': driverId,
        'riderID': riderId,

        // status
        'rideStatus': 'incoming',

        // copied location data
        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'pickupGeo': pickupGeo,
        'destinationGeo': destinationGeo,

        // timestamps
        'acceptedAt': now,
        'createdAt': now,
        'updatedAt': now,

        // payment
        'finalFare': null,
        'paymentStatus': 'unpaid',
      });

      // 2) update request doc
      tx.update(requestRef, {
        'status': 'incoming',
        'matchedDriverId': driverId,
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
    required String nextStatus,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final driverId = user.uid;

    final rideRef = _db.collection('rides').doc(rideId);

    await _db.runTransaction((tx) async {
      // ✅ READ #1 (always)
      final rideSnap = await tx.get(rideRef);
      if (!rideSnap.exists) throw Exception('Ride not found');

      final ride = rideSnap.data() as Map<String, dynamic>;
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

      // ✅ If completed, READ request BEFORE ANY WRITE
      DocumentReference<Map<String, dynamic>>? reqRef;
      DocumentSnapshot<Map<String, dynamic>>? reqSnap;

      if (nextStatus == 'completed') {
        // ✅ support both keys
        final requestId =
        (ride['requestId'] ?? ride['requestID'] ?? '').toString();
        if (requestId.isNotEmpty) {
          reqRef = _db.collection('riderRequests').doc(requestId);
          reqSnap = await tx.get(reqRef);
        }
      }

      // ✅ NOW DO WRITES (after all reads)
      tx.update(rideRef, updates);

      if (nextStatus == 'completed' && reqRef != null && (reqSnap?.exists ?? false)) {
        tx.update(reqRef, {
          'status': 'completed',
          'updatedAt': now,
        });
      }
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
// CANCELLATION
// =====================================================
extension RideCancellation on RideRepository {
  Future<void> cancelRideByRider({required String rideId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final rideRef = _rides.doc(rideId);

    await _db.runTransaction((tx) async {
      final rideSnap = await tx.get(rideRef);
      if (!rideSnap.exists) throw Exception('Ride not found');

      final ride = rideSnap.data()!;
      final status = (ride['rideStatus'] ?? '').toString();
      final riderId = (ride['riderID'] ?? '').toString();

      if (riderId != user.uid) throw Exception('Not authorized');

      // ✅ Rider can cancel only before trip starts
      if (status != 'incoming') {
        throw Exception('Cannot cancel after the trip starts');
      }

      final requestId =
      (ride['requestId'] ?? ride['requestID'] ?? '').toString();

      final now = FieldValue.serverTimestamp();

      tx.update(rideRef, {
        'rideStatus': 'cancelled',
        'cancelledBy': 'rider',
        'cancelledAt': now,
        'updatedAt': now,
      });

      if (requestId.isNotEmpty) {
        final reqRef = _db.collection('riderRequests').doc(requestId);
        final reqSnap = await tx.get(reqRef);
        if (reqSnap.exists) {
          tx.update(reqRef, {
            'status': 'cancelled',
            'updatedAt': now,
          });
        }
      }
    });
  }

  Future<void> cancelRideByDriver({required String rideId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final rideRef = _rides.doc(rideId);

    await _db.runTransaction((tx) async {
      final rideSnap = await tx.get(rideRef);
      if (!rideSnap.exists) throw Exception('Ride not found');

      final ride = rideSnap.data()!;
      final status = (ride['rideStatus'] ?? '').toString();
      final driverId = (ride['driverID'] ?? '').toString();

      if (driverId != user.uid) throw Exception('Not authorized');

      // ✅ Driver can cancel before ongoing
      final canCancel = status == 'incoming' || status == 'arrived_pickup';
      if (!canCancel) {
        throw Exception('Cannot cancel after the trip starts');
      }

      final requestId =
      (ride['requestId'] ?? ride['requestID'] ?? '').toString();

      final now = FieldValue.serverTimestamp();

      tx.update(rideRef, {
        'rideStatus': 'cancelled',
        'cancelledBy': 'driver',
        'cancelledAt': now,
        'updatedAt': now,
      });

      if (requestId.isNotEmpty) {
        final reqRef = _db.collection('riderRequests').doc(requestId);
        final reqSnap = await tx.get(reqRef);
        if (reqSnap.exists) {
          tx.update(reqRef, {
            'status': 'cancelled',
            'updatedAt': now,
          });
        }
      }
    });
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
