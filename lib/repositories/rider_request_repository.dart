import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ✅ Custom exception for active ride/request
class ActiveRideExistsException implements Exception {
  final String message;
  ActiveRideExistsException([
    this.message = 'You already have an active ride/request.',
  ]);
  @override
  String toString() => message;
}

/// ✅ Wallet minimum exception
class WalletMinimumException implements Exception {
  final String message;
  WalletMinimumException([this.message = 'Wallet balance must be at least RM10.']);
  @override
  String toString() => message;
}

class RiderRequestRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('riderRequests');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ✅ NEW: offers collection (matches DriverOfferRepository)
  CollectionReference<Map<String, dynamic>> get _offers =>
      _db.collection('driver_offers');

  /// statuses considered "active" (cannot create another request)
  static const activeStatuses = [
    'waiting',
    'incoming',
    'arrived_pickup',
    'ongoing',
    'arrived_destination',
  ];

  static const int _minWalletToCreateCents = 1000; // RM10
  static const Duration _preRideWindow = Duration(minutes: 30);

  /// ✅ Convert DateTime -> rideDate + rideTime strings
  Map<String, String> _dateTimeToStrings(DateTime dt) {
    final rideDate =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final rideTime =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return {'rideDate': rideDate, 'rideTime': rideTime};
  }

  /// ✅ Check if current rider has any active request
  Future<void> _ensureNoActiveRequest(String uid) async {
    final existing = await _requests
        .where('riderId', isEqualTo: uid)
        .where('status', whereIn: activeStatuses)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw ActiveRideExistsException(
        'You already have an active ride/request. Please cancel or finish it first.',
      );
    }
  }

  /// ✅ Must have at least RM10 to create request
  Future<void> _ensureWalletMinToCreate(String uid) async {
    final userSnap = await _users.doc(uid).get();
    if (!userSnap.exists) throw ('User not found');

    final data = userSnap.data() as Map<String, dynamic>;
    final wallet = (data['walletBalance'] as num?)?.toInt() ?? 0;

    if (wallet < _minWalletToCreateCents) {
      throw WalletMinimumException(
        'Wallet balance must be at least RM10 to create a request.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ NEW: Accept driver offer -> create riderRequests + decrement seats
  // ---------------------------------------------------------------------------
  Future<String> acceptOfferAndCreateRequest({
    required String offerId,
    required int seatRequested,
    required double routeDistanceKm,
    required String routeDurationText,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw ('Not logged in');

    await _ensureNoActiveRequest(user.uid);
    await _ensureWalletMinToCreate(user.uid);

    if (seatRequested <= 0) throw ('Invalid seatRequested');
    if (routeDistanceKm <= 0) throw ('Invalid distance');
    if (routeDurationText.trim().isEmpty) throw ('Invalid duration');

    final offerRef = _offers.doc(offerId);
    final reqRef = _requests.doc();
    final requestId = reqRef.id;

    await _db.runTransaction((tx) async {
      final offerSnap = await tx.get(offerRef);
      if (!offerSnap.exists) throw ('Offer not found');

      final offer = offerSnap.data()!;
      final status = (offer['status'] ?? '').toString();
      final seatsAvailable = (offer['seatsAvailable'] as num?)?.toInt() ?? 0;

      if (status != 'open') throw ('Offer is not open');
      if (seatsAvailable < seatRequested) throw ('Not enough seats available');

      final rideTs = offer['rideDateTime'];
      if (rideTs is! Timestamp) throw ('Offer rideDateTime missing');

      final pickupGeo = offer['pickupGeo'];
      final destinationGeo = offer['destinationGeo'];
      if (pickupGeo is! GeoPoint || destinationGeo is! GeoPoint) {
        throw ('Offer pickup/destination Geo missing');
      }

      final rideDt = rideTs.toDate();
      final strings = _dateTimeToStrings(rideDt);

      // ✅ Decide scheduled vs waiting based on time window
      final now = DateTime.now();
      final isTooEarly = rideDt.isAfter(now.add(_preRideWindow));
      final requestStatus = isTooEarly ? 'scheduled' : 'waiting';

      // Offer fare is RM double, riderRequests finalFare is cents int
      final fareRm = (offer['fare'] as num?)?.toDouble() ?? 0.0;
      if (fareRm <= 0) throw ('Invalid offer fare');

      final finalFareCents = (fareRm * 100).round() * seatRequested;

      tx.set(reqRef, {
        'requestId': requestId,

        'pickupAddress': (offer['pickup'] ?? '').toString().trim(),
        'destinationAddress': (offer['destination'] ?? '').toString().trim(),
        'pickupGeo': pickupGeo,
        'destinationGeo': destinationGeo,

        'rideDate': strings['rideDate'],
        'rideTime': strings['rideTime'],
        'seatRequested': seatRequested,

        // ✅ scheduled if too early, otherwise waiting
        'status': requestStatus,
        'activeRideId': null,

        // ✅ ALWAYS store scheduledAt from offer rideDateTime
        'scheduledAt': Timestamp.fromDate(rideDt),

        'finalFare': finalFareCents,
        'routeDistanceKm': routeDistanceKm,
        'routeDurationText': routeDurationText,

        // keep schema consistent
        'searchRadiusKm': 0.0,
        'maxRadiusKm': 0.0,
        'searchStepKm': 0.0,
        'nextExpandAt': null,
        'notifiedDriverIds': <String>[],

        // direct match
        'matchedDriverId': (offer['driverId'] ?? '').toString(),
        'offerId': offerId,

        // payment placeholders
        'hold': null,
        'acceptedAt': null,

        'riderId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

// ✅ Single-accept offer: once accepted, lock it immediately
      final newSeats = seatsAvailable - seatRequested;

// You can still store seatsAvailable for record, but status becomes booked no matter what.
      tx.update(offerRef, {
        'seatsAvailable': newSeats,
        'status': 'booked', // ✅ immediately hide from open offers
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return requestId;
  }

  // ---------------------------------------------------------------------------
  // ✅ Your existing methods unchanged below
  // ---------------------------------------------------------------------------

  Future<String> createRiderRequest({
    required String pickupAddress,
    required String destinationAddress,
    required GeoPoint pickupGeo,
    required GeoPoint destinationGeo,
    required String rideDate,
    required String rideTime,
    required int seatRequested,

    required int finalFareCents,
    required double routeDistanceKm,
    required String routeDurationText,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw ('Not logged in');

    await _ensureNoActiveRequest(user.uid);
    await _ensureWalletMinToCreate(user.uid);

    if (finalFareCents <= 0) throw ('Invalid fare');
    if (routeDistanceKm <= 0) throw ('Invalid distance');
    if (routeDurationText.trim().isEmpty) throw ('Invalid duration');

    final doc = _requests.doc();
    final requestId = doc.id;

    await doc.set({
      'requestId': requestId,
      'pickupAddress': pickupAddress.trim(),
      'destinationAddress': destinationAddress.trim(),
      'pickupGeo': pickupGeo,
      'destinationGeo': destinationGeo,

      'rideDate': rideDate,
      'rideTime': rideTime,
      'seatRequested': seatRequested,

      'status': 'waiting',
      'activeRideId': null,
      'scheduledAt': null,

      'finalFare': finalFareCents,
      'routeDistanceKm': routeDistanceKm,
      'routeDurationText': routeDurationText,

      'searchRadiusKm': 2.0,
      'maxRadiusKm': 20.0,
      'searchStepKm': 2.0,
      'nextExpandAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(seconds: 30)),
      ),
      'notifiedDriverIds': <String>[],

      'riderId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return requestId;
  }

  Future<String> createScheduledRiderRequest({
    required String pickupAddress,
    required String destinationAddress,
    required GeoPoint pickupGeo,
    required GeoPoint destinationGeo,
    required DateTime scheduledAt,
    required int seatRequested,

    required int finalFareCents,
    required double routeDistanceKm,
    required String routeDurationText,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw ('Not logged in');

    await _ensureNoActiveRequest(user.uid);
    await _ensureWalletMinToCreate(user.uid);
    await _ensureNoScheduledClash(user.uid, scheduledAt);

    if (finalFareCents <= 0) throw ('Invalid fare');
    if (routeDistanceKm <= 0) throw ('Invalid distance');
    if (routeDurationText.trim().isEmpty) throw ('Invalid duration');

    final strings = _dateTimeToStrings(scheduledAt);

    final doc = _requests.doc();
    final requestId = doc.id;

    await doc.set({
      'requestId': requestId,
      'pickupAddress': pickupAddress.trim(),
      'destinationAddress': destinationAddress.trim(),
      'pickupGeo': pickupGeo,
      'destinationGeo': destinationGeo,

      'rideDate': strings['rideDate'],
      'rideTime': strings['rideTime'],
      'seatRequested': seatRequested,

      'status': 'scheduled',
      'activeRideId': null,
      'scheduledAt': Timestamp.fromDate(scheduledAt),

      'finalFare': finalFareCents,
      'routeDistanceKm': routeDistanceKm,
      'routeDurationText': routeDurationText,

      'riderId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return requestId;
  }

  Future<void> activateDueScheduledRequests() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // ✅ Activate bookings when we are within the pre-ride window
    final activateBefore = DateTime.now().add(_preRideWindow);
    final cutoff = Timestamp.fromDate(activateBefore);

    final snap = await _requests
        .where('riderId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'scheduled')
        .where('scheduledAt', isLessThanOrEqualTo: cutoff)
        .get();

    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {
        'status': 'waiting',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> _ensureNoScheduledClash(String uid, DateTime scheduledAt) async {
    const buffer = Duration(minutes: 30);

    final start = Timestamp.fromDate(scheduledAt.subtract(buffer));
    final end = Timestamp.fromDate(scheduledAt.add(buffer));

    final clash = await _requests
        .where('riderId', isEqualTo: uid)
        .where('status', isEqualTo: 'scheduled')
        .where('scheduledAt', isGreaterThanOrEqualTo: start)
        .where('scheduledAt', isLessThanOrEqualTo: end)
        .limit(1)
        .get();

    if (clash.docs.isNotEmpty) {
      throw (
      'You already have a scheduled booking around that time. Please choose a different time.',
      );
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamRequest(String requestId) {
    return _requests.doc(requestId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyScheduledRequests() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _requests
        .where('riderId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'scheduled')
        .orderBy('scheduledAt', descending: false)
        .snapshots();
  }

  Future<void> cancelRequest(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) throw ('Not logged in');

    final ref = _requests.doc(requestId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw ('Request not found');

      final d = snap.data()!;
      if (d['riderId'] != user.uid) throw ('Not your request');

      final status = (d['status'] ?? '').toString();
      if (status != 'waiting' && status != 'scheduled') {
        throw ('Cannot cancel after driver accepted');
      }

      tx.update(ref, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}