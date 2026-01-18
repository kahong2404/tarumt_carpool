import 'package:cloud_firestore/cloud_firestore.dart';

class RiderRequest {
  final String requestID; // PK
  final String origin; // address text
  final String destination; // address text
  final String rideDate; // "YYYY-MM-DD"
  final String rideTime; // "HH:mm"
  final int seatRequested;
  final String requestStatus; // pending/accepted/rejected/cancelled etc
  final String riderId; // FK -> users/{uid}
  final Timestamp? createdAt;

  RiderRequest({
    required this.requestID,
    required this.origin,
    required this.destination,
    required this.rideDate,
    required this.rideTime,
    required this.seatRequested,
    required this.requestStatus,
    required this.riderId,
    this.createdAt,
  });

  Map<String, dynamic> toMapForCreate() {
    return {
      'requestID': requestID,
      'origin': origin,
      'destination': destination,
      'rideDate': rideDate,
      'rideTime': rideTime,
      'seatRequested': seatRequested,
      'requestStatus': requestStatus,
      'riderId': riderId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory RiderRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RiderRequest(
      requestID: (data['requestID'] ?? doc.id).toString(),
      origin: (data['origin'] ?? '').toString(),
      destination: (data['destination'] ?? '').toString(),
      rideDate: (data['rideDate'] ?? '').toString(),
      rideTime: (data['rideTime'] ?? '').toString(),
      seatRequested: (data['seatRequested'] ?? 1) as int,
      requestStatus: (data['requestStatus'] ?? 'pending').toString(),
      riderId: (data['riderId'] ?? '').toString(),
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
