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

  /// statuses considered "active" (cannot create another request)
  static const activeStatuses = [
    'waiting',
    'incoming',
    'arrived_pickup',
    'ongoing',
    'arrived_destination',
  ];

  static const int _minWalletToCreateCents = 1000; // RM10

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
    if (!userSnap.exists) throw Exception('User not found');

    final data = userSnap.data() as Map<String, dynamic>;
    final wallet = (data['walletBalance'] as num?)?.toInt() ?? 0;

    if (wallet < _minWalletToCreateCents) {
      throw WalletMinimumException(
        'Wallet balance must be at least RM10 to create a request.',
      );
    }
  }

  /// ✅ Normal "create now" (immediate waiting)
  /// Stores: finalFare + distance + duration INSIDE riderRequests
  Future<String> createRiderRequest({
    required String pickupAddress,
    required String destinationAddress,
    required GeoPoint pickupGeo,
    required GeoPoint destinationGeo,
    required String rideDate,
    required String rideTime,
    required int seatRequested,

    // ✅ computed once (Directions + fare calc)
    required int finalFareCents,
    required double routeDistanceKm,
    required String routeDurationText,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    await _ensureNoActiveRequest(user.uid);
    await _ensureWalletMinToCreate(user.uid);

    if (finalFareCents <= 0) throw Exception('Invalid fare');
    if (routeDistanceKm <= 0) throw Exception('Invalid distance');
    if (routeDurationText.trim().isEmpty) throw Exception('Invalid duration');

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

      // ✅ store the final fare + real route info here
      'finalFare': finalFareCents, // cents int
      'routeDistanceKm': routeDistanceKm,
      'routeDurationText': routeDurationText,

      // ✅ matching settings
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

  /// ✅ Scheduled request (still requires RM10 min)
  Future<String> createScheduledRiderRequest({
    required String pickupAddress,
    required String destinationAddress,
    required GeoPoint pickupGeo,
    required GeoPoint destinationGeo,
    required DateTime scheduledAt,
    required int seatRequested,

    // ✅ computed once
    required int finalFareCents,
    required double routeDistanceKm,
    required String routeDurationText,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    await _ensureNoActiveRequest(user.uid);
    await _ensureWalletMinToCreate(user.uid);

    if (finalFareCents <= 0) throw Exception('Invalid fare');
    if (routeDistanceKm <= 0) throw Exception('Invalid distance');
    if (routeDurationText.trim().isEmpty) throw Exception('Invalid duration');

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

      // ✅ store the final fare + real route info here too
      'finalFare': finalFareCents,
      'routeDistanceKm': routeDistanceKm,
      'routeDurationText': routeDurationText,

      'riderId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return requestId;
  }

  /// ✅ Activate scheduled requests when time arrived
  Future<void> activateDueScheduledRequests() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = Timestamp.fromDate(DateTime.now());

    final snap = await _requests
        .where('riderId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'scheduled')
        .where('scheduledAt', isLessThanOrEqualTo: now)
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

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamRequest(String requestId) {
    return _requests.doc(requestId).snapshots();
  }

  /// Rider cancels while waiting or scheduled
  Future<void> cancelRequest(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final ref = _requests.doc(requestId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Request not found');

      final d = snap.data()!;
      if (d['riderId'] != user.uid) throw Exception('Not your request');

      final status = (d['status'] ?? '').toString();
      if (status != 'waiting' && status != 'scheduled') {
        throw Exception('Cannot cancel after driver accepted');
      }

      tx.update(ref, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
