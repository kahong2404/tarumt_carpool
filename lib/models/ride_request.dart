import 'package:cloud_firestore/cloud_firestore.dart';

class RiderRequest {
  // ------------------------
  // Identity
  // ------------------------
  final String requestID; // Firestore doc id
  final String riderId;   // users/{uid}

  // ------------------------
  // Display text (UI)
  // ------------------------
  final String originAddress;
  final String destinationAddress;

  // ------------------------
  // ✅ GeoPoints (for maps & matching)
  // ------------------------
  final GeoPoint originGeo;
  final GeoPoint destinationGeo;

  // ------------------------
  // Ride details
  // ------------------------
  final String rideDate; // "YYYY-MM-DD"
  final String rideTime; // "HH:mm"
  final int seatRequested;
  final String requestStatus; // pending / accepted / cancelled / completed

  final Timestamp? createdAt;

  // ------------------------
  // Constructor
  // ------------------------
  const RiderRequest({
    required this.requestID,
    required this.riderId,
    required this.originAddress,
    required this.destinationAddress,
    required this.originGeo,
    required this.destinationGeo,
    required this.rideDate,
    required this.rideTime,
    required this.seatRequested,
    required this.requestStatus,
    this.createdAt,
  });

  // ------------------------
  // Firestore (CREATE)
  // ------------------------
  Map<String, dynamic> toMapForCreate() {
    return {
      'requestID': requestID,
      'riderId': riderId,

      // display
      'originAddress': originAddress.trim(),
      'destinationAddress': destinationAddress.trim(),

      // ✅ geo
      'originGeo': originGeo,
      'destinationGeo': destinationGeo,

      'rideDate': rideDate,
      'rideTime': rideTime,
      'seatRequested': seatRequested,
      'requestStatus': requestStatus,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // ------------------------
  // Firestore → Model
  // ------------------------
  factory RiderRequest.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();
    if (data == null) {
      throw Exception('RiderRequest has no data: ${doc.id}');
    }

    final originGeo = data['originGeo'];
    final destinationGeo = data['destinationGeo'];

    if (originGeo is! GeoPoint || destinationGeo is! GeoPoint) {
      throw Exception('RiderRequest missing GeoPoint fields: ${doc.id}');
    }

    return RiderRequest(
      requestID: (data['requestID'] ?? doc.id).toString(),
      riderId: (data['riderId'] ?? '').toString(),

      originAddress: (data['originAddress'] ?? '').toString(),
      destinationAddress: (data['destinationAddress'] ?? '').toString(),

      originGeo: originGeo,
      destinationGeo: destinationGeo,

      rideDate: (data['rideDate'] ?? '').toString(),
      rideTime: (data['rideTime'] ?? '').toString(),
      seatRequested: (data['seatRequested'] ?? 1) as int,
      requestStatus: (data['requestStatus'] ?? 'pending').toString(),
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
