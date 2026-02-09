import 'package:cloud_firestore/cloud_firestore.dart';

/// Rider request lifecycle (your plan)
/// scheduled -> waiting -> incoming -> accepted/ongoing -> completed
/// waiting/scheduled can be cancelled
class RiderRequest {
  // ------------------------
  // Identity
  // ------------------------
  final String requestId; // Firestore doc id
  final String riderId; // users/{uid}

  // ------------------------
  // Display text (UI)
  // ------------------------
  final String pickupAddress;
  final String destinationAddress;

  // ------------------------
  // GeoPoints (for maps & matching)
  // ------------------------
  final GeoPoint pickupGeo;
  final GeoPoint destinationGeo;

  // ------------------------
  // Ride details
  // ------------------------
  final String rideDate; // "YYYY-MM-DD"
  final String rideTime; // "HH:mm"
  final int seatRequested;

  /// waiting / scheduled / incoming / accepted / ongoing / cancelled / completed
  final String status;

  // ------------------------
  // Matching fields (NEW)
  // ------------------------
  /// Current search radius (slowly increases)
  final double searchRadiusKm;

  /// Max radius allowed
  final double maxRadiusKm;

  /// Increase step
  final double searchStepKm;

  /// Next time the system should expand radius
  final Timestamp? nextExpandAt;

  /// To avoid showing/notifying same drivers repeatedly
  final List<String> notifiedDriverIds;

  /// Once accepted/locked
  final String? matchedDriverId;

  /// When driver accepts, system creates ride, put ride id here
  final String? activeRideId;

  // ------------------------
  // Scheduled fields
  // ------------------------
  final Timestamp? scheduledAt;

  // ------------------------
  // Timestamps
  // ------------------------
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const RiderRequest({
    required this.requestId,
    required this.riderId,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupGeo,
    required this.destinationGeo,
    required this.rideDate,
    required this.rideTime,
    required this.seatRequested,
    required this.status,

    // matching
    required this.searchRadiusKm,
    required this.maxRadiusKm,
    required this.searchStepKm,
    required this.notifiedDriverIds,
    this.nextExpandAt,
    this.matchedDriverId,
    this.activeRideId,

    // scheduled
    this.scheduledAt,

    // timestamps
    this.createdAt,
    this.updatedAt,
  });

  // ------------------------
  // Map (CREATE/UPDATE)
  // ------------------------
  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'riderId': riderId,
      'pickupAddress': pickupAddress.trim(),
      'destinationAddress': destinationAddress.trim(),
      'pickupGeo': pickupGeo,
      'destinationGeo': destinationGeo,
      'rideDate': rideDate,
      'rideTime': rideTime,
      'seatRequested': seatRequested,
      'status': status,

      // matching
      'searchRadiusKm': searchRadiusKm,
      'maxRadiusKm': maxRadiusKm,
      'searchStepKm': searchStepKm,
      'nextExpandAt': nextExpandAt,
      'notifiedDriverIds': notifiedDriverIds,
      'matchedDriverId': matchedDriverId,
      'activeRideId': activeRideId,

      // scheduled
      'scheduledAt': scheduledAt,

      // timestamps
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // ------------------------
  // Firestore → Model
  // ------------------------
  factory RiderRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) throw Exception('RiderRequest has no data: ${doc.id}');

    final pickupGeo = data['pickupGeo'];
    final destinationGeo = data['destinationGeo'];

    if (pickupGeo is! GeoPoint || destinationGeo is! GeoPoint) {
      throw Exception('RiderRequest missing GeoPoint fields: ${doc.id}');
    }

    final notifiedRaw = data['notifiedDriverIds'];
    final notified = (notifiedRaw is List)
        ? notifiedRaw.map((e) => e.toString()).toList()
        : <String>[];

    return RiderRequest(
      requestId: (data['requestId'] ?? doc.id).toString(),
      riderId: (data['riderId'] ?? '').toString(),
      pickupAddress: (data['pickupAddress'] ?? '').toString(),
      destinationAddress: (data['destinationAddress'] ?? '').toString(),
      pickupGeo: pickupGeo,
      destinationGeo: destinationGeo,
      rideDate: (data['rideDate'] ?? '').toString(),
      rideTime: (data['rideTime'] ?? '').toString(),
      seatRequested: (data['seatRequested'] ?? 1) as int,
      status: (data['status'] ?? 'waiting').toString(),

      // matching (defaults if old docs)
      searchRadiusKm: (data['searchRadiusKm'] is num)
          ? (data['searchRadiusKm'] as num).toDouble()
          : 2.0,
      maxRadiusKm: (data['maxRadiusKm'] is num)
          ? (data['maxRadiusKm'] as num).toDouble()
          : 20.0,
      searchStepKm: (data['searchStepKm'] is num)
          ? (data['searchStepKm'] as num).toDouble()
          : 2.0,
      nextExpandAt: data['nextExpandAt'] as Timestamp?,
      notifiedDriverIds: notified,
      matchedDriverId: data['matchedDriverId']?.toString(),
      activeRideId: data['activeRideId']?.toString(),

      // scheduled
      scheduledAt: data['scheduledAt'] as Timestamp?,

      // timestamps
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }
}
