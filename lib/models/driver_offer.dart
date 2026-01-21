import 'package:cloud_firestore/cloud_firestore.dart';

enum DriverOfferStatus { open, booked, completed, cancelled }

// ------------------------
// Helpers
// ------------------------
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

String statusToString(DriverOfferStatus s) =>
    s.toString().split('.').last;

// ------------------------
// Model
// ------------------------
class DriverOffer {
  final String? offerId; // Firestore doc id
  final String driverId;

  // Display text
  final String pickup;
  final String destination;

  // ✅ GeoPoints (important)
  final GeoPoint pickupGeo;
  final GeoPoint destinationGeo;

  final DateTime rideDateTime;
  final int seatsAvailable;
  final double fare;
  final DriverOfferStatus status;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DriverOffer({
    this.offerId,
    required this.driverId,
    required this.pickup,
    required this.destination,
    required this.pickupGeo,
    required this.destinationGeo,
    required this.rideDateTime,
    required this.seatsAvailable,
    required this.fare,
    this.status = DriverOfferStatus.open,
    this.createdAt,
    this.updatedAt,
  });

  // ------------------------
  // Copy
  // ------------------------
  DriverOffer copyWith({
    String? offerId,
    String? driverId,
    String? pickup,
    String? destination,
    GeoPoint? pickupGeo,
    GeoPoint? destinationGeo,
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
      pickupGeo: pickupGeo ?? this.pickupGeo,
      destinationGeo: destinationGeo ?? this.destinationGeo,
      rideDateTime: rideDateTime ?? this.rideDateTime,
      seatsAvailable: seatsAvailable ?? this.seatsAvailable,
      fare: fare ?? this.fare,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ------------------------
  // Firestore mapping
  // ------------------------
  Map<String, dynamic> toMapForCreate() {
    return {
      'driverId': driverId,
      'pickup': pickup.trim(),
      'destination': destination.trim(),

      // ✅ GeoPoints
      'pickupGeo': pickupGeo,
      'destinationGeo': destinationGeo,

      'rideDateTime': Timestamp.fromDate(rideDateTime),
      'seatsAvailable': seatsAvailable,
      'fare': fare,
      'status': statusToString(status),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toMapForUpdate() {
    return {
      'pickup': pickup.trim(),
      'destination': destination.trim(),
      'pickupGeo': pickupGeo,
      'destinationGeo': destinationGeo,
      'rideDateTime': Timestamp.fromDate(rideDateTime),
      'seatsAvailable': seatsAvailable,
      'fare': fare,
      'status': statusToString(status),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ------------------------
  // Firestore → Model
  // ------------------------
  static DriverOffer fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('DriverOffer has no data: ${doc.id}');
    }

    final rideTs = data['rideDateTime'] as Timestamp?;
    final createdTs = data['createdAt'] as Timestamp?;
    final updatedTs = data['updatedAt'] as Timestamp?;

    final pickupGeo = data['pickupGeo'];
    final destinationGeo = data['destinationGeo'];

    if (pickupGeo is! GeoPoint || destinationGeo is! GeoPoint) {
      throw Exception('GeoPoint missing in DriverOffer ${doc.id}');
    }

    return DriverOffer(
      offerId: doc.id,
      driverId: (data['driverId'] ?? '') as String,
      pickup: (data['pickup'] ?? '') as String,
      destination: (data['destination'] ?? '') as String,
      pickupGeo: pickupGeo,
      destinationGeo: destinationGeo,
      rideDateTime:
      (rideTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0)),
      seatsAvailable: (data['seatsAvailable'] ?? 0) as int,
      fare: (data['fare'] ?? 0).toDouble(),
      status: statusFromString((data['status'] ?? 'open') as String),
      createdAt: createdTs?.toDate(),
      updatedAt: updatedTs?.toDate(),
    );
  }
}
