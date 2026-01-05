import 'package:cloud_firestore/cloud_firestore.dart';

enum DriverOfferStatus { open, booked, completed, cancelled }

DriverOfferStatus statusFromString(String s) {
  switch (s) {
    case 'open':
      return DriverOfferStatus.open;
    case 'booked':
      return DriverOfferStatus.booked;
    case 'completed':
      return DriverOfferStatus.completed;
    case 'cancelled':
      return DriverOfferStatus.cancelled;
    default:
      return DriverOfferStatus.open;
  }
}

String statusToString(DriverOfferStatus s) {
  return s.toString().split('.').last; // open/booked/...
}

class DriverOffer {
  final String? offerId; // firestore doc id
  final String driverId;

  final String pickup;
  final String destination;
  final DateTime rideDateTime;

  final int seatsAvailable;
  final double fare;

  final DriverOfferStatus status;

  final DateTime? createdAt; // server timestamp -> may be null on first create
  final DateTime? updatedAt;

  const DriverOffer({
    this.offerId,
    required this.driverId,
    required this.pickup,
    required this.destination,
    required this.rideDateTime,
    required this.seatsAvailable,
    required this.fare,
    this.status = DriverOfferStatus.open,
    this.createdAt,
    this.updatedAt,
  });

  DriverOffer copyWith({
    String? offerId,
    String? driverId,
    String? pickup,
    String? destination,
    DateTime? rideDateTime,
    int? seatsAvailable,
    double? fare,
    DriverOfferStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriverOffer(
      offerId: offerId ?? this.offerId,
      driverId: driverId ?? this.driverId,
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      rideDateTime: rideDateTime ?? this.rideDateTime,
      seatsAvailable: seatsAvailable ?? this.seatsAvailable,
      fare: fare ?? this.fare,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMapForCreate() {
    // For create: timestamps should be server-generated
    return {
      'driverId': driverId,
      'pickup': pickup.trim(),
      'destination': destination.trim(),
      'rideDateTime': Timestamp.fromDate(rideDateTime),
      'seatsAvailable': seatsAvailable,
      'fare': fare,
      'status': statusToString(status),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toMapForUpdate() {
    // For update: only fields that exist in this object (full update)
    return {
      'pickup': pickup.trim(),
      'destination': destination.trim(),
      'rideDateTime': Timestamp.fromDate(rideDateTime),
      'seatsAvailable': seatsAvailable,
      'fare': fare,
      'status': statusToString(status),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DriverOffer fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('DriverOffer doc has no data: ${doc.id}');
    }

    final Timestamp? rideTs = data['rideDateTime'];
    final Timestamp? createdTs = data['createdAt'];
    final Timestamp? updatedTs = data['updatedAt'];

    return DriverOffer(
      offerId: doc.id,
      driverId: (data['driverId'] ?? '') as String,
      pickup: (data['pickup'] ?? '') as String,
      destination: (data['destination'] ?? '') as String,
      rideDateTime: (rideTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0)),
      seatsAvailable: (data['seatsAvailable'] ?? 0) as int,
      fare: (data['fare'] ?? 0).toDouble(),
      status: statusFromString((data['status'] ?? 'open') as String),
      createdAt: createdTs?.toDate(),
      updatedAt: updatedTs?.toDate(),
    );
  }
}
