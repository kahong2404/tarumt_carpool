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

  static const activeDrivers = [
    'approved'
  ];

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('riderRequests');

  CollectionReference<Map<String, dynamic>> get _rides => _db.collection('rides');

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  // Add near your other collection refs in RideRepository
  CollectionReference<Map<String, dynamic>> get _walletTx => _db.collection('walletTransactions');
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

  Stream<QuerySnapshot<Map<String, dynamic>>> streamDriverActiveRide(String driverId) {
    return _rides
        .where('driverID', isEqualTo: driverId)
        .where('rideStatus', whereIn: activeStatuses)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRiderActiveRequest(String riderId) {
    return _db
        .collection('riderRequests')
        .where('riderId', isEqualTo: riderId)
        .where('status', whereIn: const ['waiting', 'scheduled', 'incoming'])
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
  // ACCEPT REQUEST (COPY finalFare + HOLD)
  // ----------------------------
  /// Flow:
  /// riderRequests.status: waiting -> incoming
  /// rides.rideStatus: incoming
  ///
  /// ✅ ALSO:
  /// - copy riderRequests.finalFare -> rides.finalFare
  /// - "hold" = deduct rider walletBalance immediately
  /// - store hold info in riderRequests.hold (hidden)
  Future<String> acceptRequest({required String requestId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final currentDriverId = user.uid;

    // ✅ PRE-CHECK: driver can't accept if already has active ride
    final activeRideSnap = await _rides
        .where('driverID', isEqualTo: currentDriverId)
        .where('driverStatus', isEqualTo: activeDrivers)
        .where('rideStatus', whereIn: activeStatuses)
        .limit(1)
        .get();

    if (activeRideSnap.docs.isNotEmpty) {
      throw Exception('You already have an active ride.');
    }

    return _db.runTransaction<String>((tx) async {
      // --------------------
      // READS (before writes)
      // --------------------
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

      // ✅ finalFare must already exist in riderRequests (cents int)
      final fareCents = (req['finalFare'] as num?)?.toInt();
      if (fareCents == null || fareCents <= 0) {
        throw Exception('Fare not ready yet. Please try again.');
      }

      // ✅ prevent double hold
      final holdMap = (req['hold'] is Map)
          ? Map<String, dynamic>.from(req['hold'] as Map)
          : null;
      final holdStatus = (holdMap?['status'] ?? 'none').toString();
      if (holdStatus == 'held' || holdStatus == 'released') {
        throw Exception('This request already has a payment hold.');
      }

      // ✅ read rider wallet
      final riderRef = _users.doc(riderId);
      final riderSnap = await tx.get(riderRef);
      if (!riderSnap.exists) throw Exception('Rider not found');

      final riderData = riderSnap.data() as Map<String, dynamic>;
      final riderWallet = (riderData['walletBalance'] as num?)?.toInt() ?? 0;

      if (riderWallet < fareCents) {
        throw Exception('Rider wallet balance is not enough.');
      }

      // --------------------
      // WRITES
      // --------------------
      final rideRef = _rides.doc();
      final now = FieldValue.serverTimestamp();

      // 1) create ride (✅ copy finalFare)
      tx.set(rideRef, {
        'requestId': requestId,
        'offerId': null,
        'driverID': currentDriverId,
        'riderID': riderId,

        'rideStatus': 'incoming',

        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'pickupGeo': pickupGeo,
        'destinationGeo': destinationGeo,

        'acceptedAt': now,
        'createdAt': now,
        'updatedAt': now,

        // ✅ payment
        'finalFare': fareCents,     // cents
        'paymentStatus': 'held',    // held
      });

      // 2) deduct rider wallet immediately (hold)
      tx.update(riderRef, {
        'walletBalance': riderWallet - fareCents,
        'updatedAt': now,
      });

      // 3) update request doc (status + hidden hold)
      tx.update(requestRef, {
        'status': 'incoming',
        'matchedDriverId': currentDriverId,
        'activeRideId': rideRef.id,
        'acceptedAt': now,
        'updatedAt': now,

        'hold': {
          'status': 'held',
          'amount': fareCents,
          'heldAt': now,
          'releasedAt': null,
          'refundedAt': null,
        },
      });

      return rideRef.id;
    });
  }
}

// =====================================================
// STATUS TRANSITIONS (✅ RELEASE ON COMPLETED)
// =====================================================
// =====================================================
// STATUS TRANSITIONS (✅ RELEASE ON COMPLETED + WALLET TX)
// =====================================================
extension RideStatusTransitions on RideRepository {
  Future<void> updateRideStatus({
    required String rideId,
    required String nextStatus,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final currentDriverId = user.uid;

    final rideRef = _db.collection('rides').doc(rideId);

    await _db.runTransaction((tx) async {
      // --------------------
      // READS (before writes)
      // --------------------
      final rideSnap = await tx.get(rideRef);
      if (!rideSnap.exists) throw Exception('Ride not found');

      final ride = rideSnap.data() as Map<String, dynamic>;

      // ✅ Only driver of this ride can update status
      final rideDriverId = (ride['driverID'] ?? '').toString();
      if (rideDriverId != currentDriverId) throw Exception('Not authorized');

      final current = (ride['rideStatus'] ?? '').toString();
      if (!_isValidTransition(current, nextStatus)) {
        throw Exception('Invalid status transition');
      }

      final now = FieldValue.serverTimestamp();

      // Completed extra reads
      DocumentReference<Map<String, dynamic>>? reqRef;
      DocumentSnapshot<Map<String, dynamic>>? reqSnap;

      DocumentReference<Map<String, dynamic>>? driverRef;
      DocumentSnapshot<Map<String, dynamic>>? driverSnap;

      // ✅ wallet tx (release)
      DocumentReference<Map<String, dynamic>>? walletTxRef;
      DocumentSnapshot<Map<String, dynamic>>? walletTxSnap;

      String? requestIdForRef;
      String? riderIdForRef;

      int? fareCents;
      Map<String, dynamic>? hold;

      if (nextStatus == 'completed') {
        // ✅ prevent double release
        final currentPay = (ride['paymentStatus'] ?? '').toString();
        if (currentPay == 'released') throw Exception('Payment already released.');
        if (currentPay == 'refunded') throw Exception('Payment already refunded.');

        requestIdForRef =
            (ride['requestId'] ?? ride['requestID'] ?? '').toString();
        if (requestIdForRef.isEmpty) throw Exception('Ride missing requestId');

        riderIdForRef = (ride['riderID'] ?? '').toString();
        if (riderIdForRef.isEmpty) throw Exception('Ride missing riderID');

        reqRef = _db.collection('riderRequests').doc(requestIdForRef);
        reqSnap = await tx.get(reqRef);
        if (!reqSnap.exists) throw Exception('Request not found');

        final reqData = reqSnap.data()!;
        hold = (reqData['hold'] is Map)
            ? Map<String, dynamic>.from(reqData['hold'] as Map)
            : null;

        final holdStatus = (hold?['status'] ?? 'none').toString();
        if (holdStatus != 'held') {
          throw Exception('No held payment to release.');
        }

        // fare from ride preferred
        fareCents = (ride['finalFare'] as num?)?.toInt() ??
            (hold?['amount'] as num?)?.toInt();

        if (fareCents == null || fareCents <= 0) {
          throw Exception('Invalid fare to release.');
        }

        // ✅ credit driver walletBalance
        driverRef = _db.collection('users').doc(rideDriverId);
        driverSnap = await tx.get(driverRef);
        if (!driverSnap.exists) throw Exception('Driver user not found');

        // ✅ prepare wallet tx ref + read once (idempotent)
        walletTxRef = _walletTx.doc('release_$rideId');
        walletTxSnap = await tx.get(walletTxRef);
      }

      // --------------------
      // WRITES
      // --------------------
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
        updates['paymentStatus'] = 'released';
      }

      tx.update(rideRef, updates);

      // ✅ mirror request status update + hold released
      if (nextStatus == 'completed' &&
          reqRef != null &&
          reqSnap != null &&
          reqSnap.exists) {
        tx.update(reqRef, {
          'status': 'completed',
          'updatedAt': now,
          'hold': {
            ...(hold ?? {}),
            'status': 'released',
            'releasedAt': now,
          },
        });
      }

      // ✅ credit driver walletBalance
      if (nextStatus == 'completed' &&
          driverRef != null &&
          driverSnap != null) {
        final d = driverSnap.data() as Map<String, dynamic>;
        final driverWallet = (d['walletBalance'] as num?)?.toInt() ?? 0;

        tx.update(driverRef, {
          'walletBalance': driverWallet + (fareCents ?? 0),
          'updatedAt': now,
        });
      }

      // ✅ record wallet transaction history for driver (release)
      if (nextStatus == 'completed' &&
          walletTxRef != null &&
          walletTxSnap != null &&
          !walletTxSnap.exists) {
        tx.set(walletTxRef, {
          'type': 'release',
          'status': 'posted',
          'amountCents': fareCents ?? 0,

          // for querying driver history
          'walletOwnerUid': rideDriverId,

          // audit trail
          'fromUid': riderIdForRef,
          'toUid': rideDriverId,

          'rideId': rideId,
          'requestId': requestIdForRef,
          'createdAt': now,
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
// CANCELLATION (✅ REFUND IF HELD)
// =====================================================
extension RideCancellation on RideRepository {
  Future<void> cancelRideByRider({required String rideId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final rideRef = _db.collection('rides').doc(rideId);

    await _db.runTransaction((tx) async {
      // READS
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

      // ✅ prevent double refund
      final currentPay = (ride['paymentStatus'] ?? '').toString();
      if (currentPay == 'refunded') throw Exception('Payment already refunded.');
      if (currentPay == 'released') throw Exception('Payment already released.');

      final requestId = (ride['requestId'] ?? ride['requestID'] ?? '').toString();
      final now = FieldValue.serverTimestamp();

      // If held, refund
      DocumentReference<Map<String, dynamic>>? reqRef;
      DocumentSnapshot<Map<String, dynamic>>? reqSnap;
      DocumentReference<Map<String, dynamic>>? riderRef;
      DocumentSnapshot<Map<String, dynamic>>? riderSnap;
      Map<String, dynamic>? hold;
      int? refundCents;

      if (requestId.isNotEmpty) {
        reqRef = _db.collection('riderRequests').doc(requestId);
        reqSnap = await tx.get(reqRef);

        if (reqSnap.exists) {
          final req = reqSnap.data()!;
          hold = (req['hold'] is Map)
              ? Map<String, dynamic>.from(req['hold'] as Map)
              : null;

          final holdStatus = (hold?['status'] ?? 'none').toString();
          if (holdStatus == 'held') {
            refundCents = (hold?['amount'] as num?)?.toInt()
                ?? (ride['finalFare'] as num?)?.toInt();

            riderRef = _db.collection('users').doc(riderId);
            riderSnap = await tx.get(riderRef);
            if (!riderSnap.exists) throw Exception('Rider user not found');
          }
        }
      }

      // WRITES
      tx.update(rideRef, {
        'rideStatus': 'cancelled',
        'cancelledBy': 'rider',
        'cancelledAt': now,
        'updatedAt': now,
        'paymentStatus': (refundCents != null) ? 'refunded' : currentPay,
      });

      if (reqRef != null && reqSnap != null && reqSnap.exists) {
        tx.update(reqRef, {
          'status': 'cancelled',
          'updatedAt': now,
          if (refundCents != null)
            'hold': {
              ...(hold ?? {}),
              'status': 'refunded',
              'refundedAt': now,
            },
        });
      }

      if (refundCents != null && riderRef != null && riderSnap != null) {
        final rd = riderSnap.data() as Map<String, dynamic>;
        final wallet = (rd['walletBalance'] as num?)?.toInt() ?? 0;

        tx.update(riderRef, {
          'walletBalance': wallet + refundCents!,
          'updatedAt': now,
        });
      }
    });
  }

  Future<void> cancelRideByDriver({required String rideId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final rideRef = _db.collection('rides').doc(rideId);

    await _db.runTransaction((tx) async {
      // READS
      final rideSnap = await tx.get(rideRef);
      if (!rideSnap.exists) throw Exception('Ride not found');

      final ride = rideSnap.data()!;
      final status = (ride['rideStatus'] ?? '').toString();
      final rideDriverId = (ride['driverID'] ?? '').toString();

      if (rideDriverId != user.uid) throw Exception('Not authorized');

      // ✅ Driver can cancel before ongoing
      final canCancel = status == 'incoming' || status == 'arrived_pickup';
      if (!canCancel) {
        throw Exception('Cannot cancel after the trip starts');
      }

      // ✅ prevent double refund
      final currentPay = (ride['paymentStatus'] ?? '').toString();
      if (currentPay == 'refunded') throw Exception('Payment already refunded.');
      if (currentPay == 'released') throw Exception('Payment already released.');

      final requestId = (ride['requestId'] ?? ride['requestID'] ?? '').toString();
      final riderId = (ride['riderID'] ?? '').toString();
      final now = FieldValue.serverTimestamp();

      // If held, refund rider
      DocumentReference<Map<String, dynamic>>? reqRef;
      DocumentSnapshot<Map<String, dynamic>>? reqSnap;
      DocumentReference<Map<String, dynamic>>? riderRef;
      DocumentSnapshot<Map<String, dynamic>>? riderSnap;
      Map<String, dynamic>? hold;
      int? refundCents;

      if (requestId.isNotEmpty) {
        reqRef = _db.collection('riderRequests').doc(requestId);
        reqSnap = await tx.get(reqRef);

        if (reqSnap.exists) {
          final req = reqSnap.data()!;
          hold = (req['hold'] is Map)
              ? Map<String, dynamic>.from(req['hold'] as Map)
              : null;

          final holdStatus = (hold?['status'] ?? 'none').toString();
          if (holdStatus == 'held') {
            refundCents = (hold?['amount'] as num?)?.toInt()
                ?? (ride['finalFare'] as num?)?.toInt();

            riderRef = _db.collection('users').doc(riderId);
            riderSnap = await tx.get(riderRef);
            if (!riderSnap.exists) throw Exception('Rider user not found');
          }
        }
      }

      // WRITES
      tx.update(rideRef, {
        'rideStatus': 'cancelled',
        'cancelledBy': 'driver',
        'cancelledAt': now,
        'updatedAt': now,
        'paymentStatus': (refundCents != null) ? 'refunded' : currentPay,
      });

      if (reqRef != null && reqSnap != null && reqSnap.exists) {
        tx.update(reqRef, {
          'status': 'cancelled',
          'updatedAt': now,
          if (refundCents != null)
            'hold': {
              ...(hold ?? {}),
              'status': 'refunded',
              'refundedAt': now,
            },
        });
      }

      if (refundCents != null && riderRef != null && riderSnap != null) {
        final rd = riderSnap.data() as Map<String, dynamic>;
        final wallet = (rd['walletBalance'] as num?)?.toInt() ?? 0;

        tx.update(riderRef, {
          'walletBalance': wallet + refundCents!,
          'updatedAt': now,
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
