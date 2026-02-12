import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ride.dart';

class RideRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ ONLY ride statuses (not request status)
  static const activeStatuses = [
    'incoming',
    'arrived_pickup',
    'ongoing',
    'arrived_destination',
  ];

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('riderRequests');

  CollectionReference<Map<String, dynamic>> get _rides => _db.collection('rides');

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _walletTx =>
      _db.collection('walletTransactions');

  // =====================================================
  // PRICING (ESCROW HOLD AMOUNT)
  // =====================================================
  // Keep ONE pricing formula here so accept/cancel/complete are consistent.
  static const double _baseFare = 2.00;
  static const double _ratePerKm = 0.80;
  static const double _minFare = 3.00;
  static const double _maxFare = 50.00;

  static int _toCents(double rm) => (rm * 100).round();

  static double _clampFare(double rm) {
    final withMin = rm < _minFare ? _minFare : rm;
    final capped = withMin > _maxFare ? _maxFare : withMin;
    return double.parse(capped.toStringAsFixed(2));
  }

  /// Simple haversine distance (km) from two geopoints
  static double _distanceKm(GeoPoint a, GeoPoint b) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);

  static int _estimateFareCents({
    required GeoPoint pickupGeo,
    required GeoPoint destinationGeo,
  }) {
    final km = _distanceKm(pickupGeo, destinationGeo);
    final rm = _clampFare(_baseFare + (_ratePerKm * km));
    return _toCents(rm);
  }

  // =====================================================
  // STREAMS
  // =====================================================
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

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamRide(String rideId) {
    return _rides.doc(rideId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamDriverActiveRide(
      String driverId,
      ) {
    return _rides
        .where('driverID', isEqualTo: driverId)
        .where('rideStatus', whereIn: activeStatuses)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRiderActiveRequest(
      String riderId,
      ) {
    return _db
        .collection('riderRequests')
        .where('riderId', isEqualTo: riderId)
        .where('status', whereIn: const ['waiting', 'scheduled', 'incoming'])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamDriverRideHistory(
      String driverId,
      ) {
    return _rides
        .where('driverID', isEqualTo: driverId)
        .where('rideStatus', whereIn: const ['completed', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRiderActiveRide(
      String riderId,
      ) {
    return _rides
        .where('riderID', isEqualTo: riderId)
        .where('rideStatus', whereIn: activeStatuses)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRiderRideHistory(
      String riderId,
      ) {
    return _rides
        .where('riderID', isEqualTo: riderId)
        .where('rideStatus', whereIn: const ['completed', 'cancelled'])
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();
  }

  // =====================================================
  // ACCEPT REQUEST + HOLD PAYMENT (ATOMIC)
  // =====================================================
  /// Flow:
  /// 1) riderRequests.status: waiting -> incoming
  /// 2) create rides doc incoming
  /// 3) HOLD rider wallet immediately (deduct walletBalance)
  Future<String> acceptRequest({required String requestId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final driverId = user.uid;

    // driver can't accept if already has active ride
    final activeRideSnap = await _rides
        .where('driverID', isEqualTo: driverId)
        .where('rideStatus', whereIn: activeStatuses)
        .limit(1)
        .get();

    if (activeRideSnap.docs.isNotEmpty) {
      throw Exception('You already have an active ride.');
    }

    return _db.runTransaction<String>((tx) async {
      final requestRef = _requests.doc(requestId);
      final requestSnap = await tx.get(requestRef);

      if (!requestSnap.exists) throw Exception('Request not found');

      final req = requestSnap.data()!;
      final status = (req['status'] ?? '').toString();

      if (status != 'waiting') {
        throw Exception('Request already accepted/cancelled/expired');
      }

      final existingMatched = req['matchedDriverId'];
      if (existingMatched != null && existingMatched.toString().isNotEmpty) {
        throw Exception('Request already taken by another driver.');
      }

      final riderId = (req['riderId'] ?? '').toString();
      if (riderId.isEmpty) throw Exception('Request missing riderId');

      final pickupAddress = (req['pickupAddress'] ?? '').toString();
      final destinationAddress = (req['destinationAddress'] ?? '').toString();
      final pickupGeo = req['pickupGeo'];
      final destinationGeo = req['destinationGeo'];

      if (pickupGeo is! GeoPoint || destinationGeo is! GeoPoint) {
        throw Exception('Request missing pickup/destination GeoPoint');
      }

      // ✅ compute escrow amount (cents)
      final fareCents = _estimateFareCents(
        pickupGeo: pickupGeo,
        destinationGeo: destinationGeo,
      );

      // ✅ READ rider wallet before any writes
      final riderUserRef = _users.doc(riderId);
      final riderUserSnap = await tx.get(riderUserRef);
      if (!riderUserSnap.exists) throw Exception('Rider user not found');

      final riderData = riderUserSnap.data() ?? {};
      final walletBalance = (riderData['walletBalance'] ?? 0) as int;

      if (walletBalance < fareCents) {
        throw Exception('Rider wallet balance is insufficient for this ride.');
      }

      final rideRef = _rides.doc();
      final now = FieldValue.serverTimestamp();

      // ✅ WRITES after all reads
      // 1) create ride
      tx.set(rideRef, {
        'requestId': requestId,
        'offerId': null,
        'driverID': driverId,
        'riderID': riderId,

        'rideStatus': 'incoming',

        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'pickupGeo': pickupGeo,
        'destinationGeo': destinationGeo,

        'acceptedAt': now,
        'createdAt': now,
        'updatedAt': now,

        // payment escrow fields
        'fareCentsHeld': fareCents,
        'paymentStatus': 'held', // ✅ held immediately
        'finalFare': null,
      });

      // 2) update request
      tx.update(requestRef, {
        'status': 'incoming',
        'matchedDriverId': driverId,
        'activeRideId': rideRef.id,
        'acceptedAt': now,
        'updatedAt': now,
      });

      // 3) HOLD: deduct rider wallet balance
      tx.update(riderUserRef, {
        'walletBalance': walletBalance - fareCents,
        'updatedAt': now,
      });

      // 4) create wallet tx for rider (hold)
      final holdTxRef = _walletTx.doc();
      tx.set(holdTxRef, {
        'uid': riderId,
        'type': 'ride_hold',
        'method': 'wallet',
        'title': 'Ride (Hold)',
        'amountCents': -fareCents,
        'status': 'success',
        'createdAt': now,
        'ref': {
          'rideId': rideRef.id,
          'requestId': requestId,
          'driverId': driverId,
        },
      });

      return rideRef.id;
    });
  }
}

// =====================================================
// STATUS TRANSITIONS + COMPLETE => PAY DRIVER
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
      // READ ride
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

      // If completed: we also need request + payout info
      DocumentReference<Map<String, dynamic>>? reqRef;
      DocumentSnapshot<Map<String, dynamic>>? reqSnap;

      // payout
      DocumentReference<Map<String, dynamic>>? driverUserRef;
      DocumentSnapshot<Map<String, dynamic>>? driverUserSnap;

      if (nextStatus == 'completed') {
        final requestId =
        (ride['requestId'] ?? ride['requestID'] ?? '').toString();
        if (requestId.isNotEmpty) {
          reqRef = _db.collection('riderRequests').doc(requestId);
          reqSnap = await tx.get(reqRef);
        }

        driverUserRef = _db.collection('users').doc(driverId);
        driverUserSnap = await tx.get(driverUserRef);

        if (driverUserSnap == null || !(driverUserSnap.exists)) {
          throw Exception('Driver user not found');
        }
      }

      // ✅ do ride write
      tx.update(rideRef, updates);

      // ✅ complete request doc
      if (nextStatus == 'completed' && reqRef != null && (reqSnap?.exists ?? false)) {
        tx.update(reqRef, {
          'status': 'completed',
          'updatedAt': now,
        });
      }

      // ✅ PAYOUT on completed
      if (nextStatus == 'completed') {
        final paymentStatus = (ride['paymentStatus'] ?? '').toString();
        if (paymentStatus != 'held') {
          // Already paid/refunded etc.
          return;
        }

        final held = ride['fareCentsHeld'];
        final heldCents = (held is int) ? held : int.tryParse(held.toString()) ?? 0;
        if (heldCents <= 0) throw Exception('Missing fareCentsHeld for payout');

        final driverData = driverUserSnap!.data() ?? {};
        final driverBal = (driverData['walletBalance'] ?? 0) as int;

        // credit driver
        tx.update(driverUserRef!, {
          'walletBalance': driverBal + heldCents,
          'updatedAt': now,
        });

        // driver wallet tx
        final earnTxRef = _db.collection('walletTransactions').doc();
        tx.set(earnTxRef, {
          'uid': driverId,
          'type': 'ride_earning',
          'method': 'wallet',
          'title': 'Ride Earning',
          'amountCents': heldCents,
          'status': 'success',
          'createdAt': now,
          'ref': {
            'rideId': rideId,
            'riderId': (ride['riderID'] ?? '').toString(),
          },
        });

        // mark ride paid + store final fare (RM)
        tx.update(rideRef, {
          'paymentStatus': 'paid',
          'finalFare': heldCents / 100.0,
          'paidAt': now,
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
// CANCELLATION => REFUND RIDER (IF HELD)
// =====================================================
extension RideCancellation on RideRepository {
  Future<void> cancelRideByRider({required String rideId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final rideRef = _db.collection('rides').doc(rideId);

    await _db.runTransaction((tx) async {
      final rideSnap = await tx.get(rideRef);
      if (!rideSnap.exists) throw Exception('Ride not found');

      final ride = rideSnap.data()!;
      final status = (ride['rideStatus'] ?? '').toString();
      final riderId = (ride['riderID'] ?? '').toString();

      if (riderId != user.uid) throw Exception('Not authorized');

      if (status != 'incoming') {
        throw Exception('Cannot cancel after the trip starts');
      }

      // Read request
      final requestId =
      (ride['requestId'] ?? ride['requestID'] ?? '').toString();
      DocumentReference<Map<String, dynamic>>? reqRef;
      DocumentSnapshot<Map<String, dynamic>>? reqSnap;
      if (requestId.isNotEmpty) {
        reqRef = _db.collection('riderRequests').doc(requestId);
        reqSnap = await tx.get(reqRef);
      }

      // payment refund
      final paymentStatus = (ride['paymentStatus'] ?? '').toString();
      final held = ride['fareCentsHeld'];
      final heldCents = (held is int) ? held : int.tryParse(held.toString()) ?? 0;

      final riderUserRef = _db.collection('users').doc(riderId);
      final riderUserSnap = await tx.get(riderUserRef);
      if (!riderUserSnap.exists) throw Exception('Rider user not found');

      final riderData = riderUserSnap.data() ?? {};
      final riderBal = (riderData['walletBalance'] ?? 0) as int;

      final now = FieldValue.serverTimestamp();

      // write ride cancelled
      tx.update(rideRef, {
        'rideStatus': 'cancelled',
        'cancelledBy': 'rider',
        'cancelledAt': now,
        'updatedAt': now,
      });

      // write request cancelled
      if (reqRef != null && (reqSnap?.exists ?? false)) {
        tx.update(reqRef, {
          'status': 'cancelled',
          'updatedAt': now,
        });
      }

      // refund if was held
      if (paymentStatus == 'held' && heldCents > 0) {
        tx.update(riderUserRef, {
          'walletBalance': riderBal + heldCents,
          'updatedAt': now,
        });

        final refundTxRef = _db.collection('walletTransactions').doc();
        tx.set(refundTxRef, {
          'uid': riderId,
          'type': 'ride_refund',
          'method': 'wallet',
          'title': 'Ride Refund',
          'amountCents': heldCents,
          'status': 'success',
          'createdAt': now,
          'ref': {
            'rideId': rideId,
            'requestId': requestId,
            'reason': 'cancelled_by_rider',
          },
        });

        tx.update(rideRef, {
          'paymentStatus': 'refunded',
          'refundedAt': now,
        });
      }
    });
  }

  Future<void> cancelRideByDriver({required String rideId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final rideRef = _db.collection('rides').doc(rideId);

    await _db.runTransaction((tx) async {
      final rideSnap = await tx.get(rideRef);
      if (!rideSnap.exists) throw Exception('Ride not found');

      final ride = rideSnap.data()!;
      final status = (ride['rideStatus'] ?? '').toString();
      final driverId = (ride['driverID'] ?? '').toString();

      if (driverId != user.uid) throw Exception('Not authorized');

      final canCancel = status == 'incoming' || status == 'arrived_pickup';
      if (!canCancel) throw Exception('Cannot cancel after the trip starts');

      final riderId = (ride['riderID'] ?? '').toString();
      if (riderId.isEmpty) throw Exception('Missing riderID');

      final requestId =
      (ride['requestId'] ?? ride['requestID'] ?? '').toString();

      DocumentReference<Map<String, dynamic>>? reqRef;
      DocumentSnapshot<Map<String, dynamic>>? reqSnap;
      if (requestId.isNotEmpty) {
        reqRef = _db.collection('riderRequests').doc(requestId);
        reqSnap = await tx.get(reqRef);
      }

      final paymentStatus = (ride['paymentStatus'] ?? '').toString();
      final held = ride['fareCentsHeld'];
      final heldCents = (held is int) ? held : int.tryParse(held.toString()) ?? 0;

      final riderUserRef = _db.collection('users').doc(riderId);
      final riderUserSnap = await tx.get(riderUserRef);
      if (!riderUserSnap.exists) throw Exception('Rider user not found');

      final riderData = riderUserSnap.data() ?? {};
      final riderBal = (riderData['walletBalance'] ?? 0) as int;

      final now = FieldValue.serverTimestamp();

      // cancel ride
      tx.update(rideRef, {
        'rideStatus': 'cancelled',
        'cancelledBy': 'driver',
        'cancelledAt': now,
        'updatedAt': now,
      });

      // cancel request
      if (reqRef != null && (reqSnap?.exists ?? false)) {
        tx.update(reqRef, {
          'status': 'cancelled',
          'updatedAt': now,
        });
      }

      // refund if held
      if (paymentStatus == 'held' && heldCents > 0) {
        tx.update(riderUserRef, {
          'walletBalance': riderBal + heldCents,
          'updatedAt': now,
        });

        final refundTxRef = _db.collection('walletTransactions').doc();
        tx.set(refundTxRef, {
          'uid': riderId,
          'type': 'ride_refund',
          'method': 'wallet',
          'title': 'Ride Refund',
          'amountCents': heldCents,
          'status': 'success',
          'createdAt': now,
          'ref': {
            'rideId': rideId,
            'requestId': requestId,
            'reason': 'cancelled_by_driver',
          },
        });

        tx.update(rideRef, {
          'paymentStatus': 'refunded',
          'refundedAt': now,
        });
      }
    });
  }
}

// =====================================================
// AUTO RESUME (ONE-TIME LOOKUP)
// =====================================================
extension RideAutoResume on RideRepository {
  Future<String?> getDriverActiveRideIdOnce(String driverId) async {
    final snap = await FirebaseFirestore.instance
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
    final snap = await FirebaseFirestore.instance
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
