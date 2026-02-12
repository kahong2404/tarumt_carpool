import 'package:cloud_firestore/cloud_firestore.dart';

enum RideStatus {
  incoming,
  arrivedPickup,
  ongoing,
  arrivedDestination,
  completed,
  cancelled,
  unknown,
}

RideStatus rideStatusFromString(String s) {
  switch (s) {
    case 'incoming':
      return RideStatus.incoming;
    case 'arrived_pickup':
      return RideStatus.arrivedPickup;
    case 'ongoing':
      return RideStatus.ongoing;
    case 'arrived_destination':
      return RideStatus.arrivedDestination;
    case 'completed':
      return RideStatus.completed;
    case 'cancelled':
      return RideStatus.cancelled;
    default:
      return RideStatus.unknown;
  }
}

String rideStatusToString(RideStatus s) {
  switch (s) {
    case RideStatus.incoming:
      return 'incoming';
    case RideStatus.arrivedPickup:
      return 'arrived_pickup';
    case RideStatus.ongoing:
      return 'ongoing';
    case RideStatus.arrivedDestination:
      return 'arrived_destination';
    case RideStatus.completed:
      return 'completed';
    case RideStatus.cancelled:
      return 'cancelled';
    case RideStatus.unknown:
      return 'unknown';
  }
}

class Ride {
  final String id;

  // relations
  final String requestId;
  final String? offerId;
  final String driverId;
  final String riderId;

  // status / location
  final RideStatus status;
  final String pickupAddress;
  final String destinationAddress;
  final GeoPoint pickupGeo;
  final GeoPoint destinationGeo;
  final GeoPoint? driverLiveLocation;

  // timestamps
  final Timestamp? acceptedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  final Timestamp? arrivedPickupAt;
  final Timestamp? startedAt;
  final Timestamp? arrivedDestinationAt;
  final Timestamp? completedAt;

  // payment
  final double? finalFare;
  final String paymentStatus; // e.g. unpaid / paid

  // review
  final bool hasReview;
  final String? reviewId;

  const Ride({
    required this.id,
    required this.requestId,
    required this.offerId,
    required this.driverId,
    required this.riderId,
    required this.status,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupGeo,
    required this.destinationGeo,
    required this.driverLiveLocation,
    required this.acceptedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.arrivedPickupAt,
    required this.startedAt,
    required this.arrivedDestinationAt,
    required this.completedAt,
    required this.finalFare,
    required this.paymentStatus,
    required this.hasReview,
    required this.reviewId,
  });

  // ----------------------------
  // Convenience
  // ----------------------------
  bool get isActive =>
      status == RideStatus.incoming ||
          status == RideStatus.arrivedPickup ||
          status == RideStatus.ongoing ||
          status == RideStatus.arrivedDestination;

  bool get isCompleted => status == RideStatus.completed;

  bool get canWriteReview => isCompleted && !hasReview;
  bool get canViewReview => isCompleted && (reviewId != null && reviewId!.trim().isNotEmpty);

  // ----------------------------
  // Firestore mapping
  // ----------------------------
  factory Ride.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) throw StateError('Ride doc ${doc.id} has no data');
    return Ride.fromMap(doc.id, data);
  }

  factory Ride.fromMap(String id, Map<String, dynamic> data) {
    GeoPoint requireGeo(String key) {
      final v = data[key];
      if (v is GeoPoint) return v;
      throw StateError('Ride $id missing $key (GeoPoint)');
    }

    Timestamp? asTs(String key) {
      final v = data[key];
      return v is Timestamp ? v : null;
    }

    GeoPoint? asGeo(String key) {
      final v = data[key];
      return v is GeoPoint ? v : null;
    }

    double? asDoubleNullable(String key) {
      final v = data[key];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final reviewRaw = (data['reviewId'] ?? '').toString().trim();
    final reviewId = reviewRaw.isEmpty ? null : reviewRaw;

    final requestId =
    (data['requestId'] ?? data['requestID'] ?? '').toString();
    final offerIdRaw = data['offerId'] ?? data['offerID'];
    final offerId = offerIdRaw == null ? null : offerIdRaw.toString();

    return Ride(
      id: id,
      requestId: requestId,
      offerId: offerId,
      driverId: (data['driverID'] ?? '').toString(),
      riderId: (data['riderID'] ?? '').toString(),
      status: rideStatusFromString((data['rideStatus'] ?? '').toString()),
      pickupAddress: (data['pickupAddress'] ?? '').toString(),
      destinationAddress: (data['destinationAddress'] ?? '').toString(),
      pickupGeo: requireGeo('pickupGeo'),
      destinationGeo: requireGeo('destinationGeo'),
      driverLiveLocation: asGeo('driverLiveLocation'),
      acceptedAt: asTs('acceptedAt'),
      createdAt: asTs('createdAt'),
      updatedAt: asTs('updatedAt'),
      arrivedPickupAt: asTs('arrivedPickupAt'),
      startedAt: asTs('startedAt'),
      arrivedDestinationAt: asTs('arrivedDestinationAt'),
      completedAt: asTs('completedAt'),
      finalFare: asDoubleNullable('finalFare'),
      paymentStatus: (data['paymentStatus'] ?? 'unpaid').toString(),
      hasReview: data['hasReview'] == true,
      reviewId: reviewId,
    );
  }

  Map<String, dynamic> toMap() {
    // ✅ Standardize on camelCase keys
    return {
      'requestId': requestId,
      'offerId': offerId,
      'driverID': driverId,
      'riderID': riderId,
      'rideStatus': rideStatusToString(status),
      'pickupAddress': pickupAddress,
      'destinationAddress': destinationAddress,
      'pickupGeo': pickupGeo,
      'destinationGeo': destinationGeo,
      'driverLiveLocation': driverLiveLocation,
      'acceptedAt': acceptedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'arrivedPickupAt': arrivedPickupAt,
      'startedAt': startedAt,
      'arrivedDestinationAt': arrivedDestinationAt,
      'completedAt': completedAt,
      'finalFare': finalFare,
      'paymentStatus': paymentStatus,
      'hasReview': hasReview,
      'reviewId': reviewId,
    };
  }

  Ride copyWith({
    String? requestId,
    String? offerId,
    String? driverId,
    String? riderId,
    RideStatus? status,
    String? pickupAddress,
    String? destinationAddress,
    GeoPoint? pickupGeo,
    GeoPoint? destinationGeo,
    GeoPoint? driverLiveLocation,
    Timestamp? acceptedAt,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    Timestamp? arrivedPickupAt,
    Timestamp? startedAt,
    Timestamp? arrivedDestinationAt,
    Timestamp? completedAt,
    double? finalFare,
    String? paymentStatus,
    bool? hasReview,
    String? reviewId,
  }) {
    return Ride(
      id: id,
      requestId: requestId ?? this.requestId,
      offerId: offerId ?? this.offerId,
      driverId: driverId ?? this.driverId,
      riderId: riderId ?? this.riderId,
      status: status ?? this.status,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      pickupGeo: pickupGeo ?? this.pickupGeo,
      destinationGeo: destinationGeo ?? this.destinationGeo,
      driverLiveLocation: driverLiveLocation ?? this.driverLiveLocation,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      arrivedPickupAt: arrivedPickupAt ?? this.arrivedPickupAt,
      startedAt: startedAt ?? this.startedAt,
      arrivedDestinationAt: arrivedDestinationAt ?? this.arrivedDestinationAt,
      completedAt: completedAt ?? this.completedAt,
      finalFare: finalFare ?? this.finalFare,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      hasReview: hasReview ?? this.hasReview,
      reviewId: reviewId ?? this.reviewId,
    );
  }
}
