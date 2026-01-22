import 'package:cloud_firestore/cloud_firestore.dart';

class DriverVerificationProfile {
  final String model;
  final String plateNumber;
  final String color;

  final String vehicleImageUrl;   // image url
  final String licensePdfUrl;     // pdf url
  final String insurancePdfUrl;   // pdf url

  final String status;            // not_applied | pending | approved | rejected
  final String? rejectReason;
  final String? approvedBy;
  final Timestamp? approvedAt;

  DriverVerificationProfile({
    required this.model,
    required this.plateNumber,
    required this.color,
    required this.vehicleImageUrl,
    required this.licensePdfUrl,
    required this.insurancePdfUrl,
    required this.status,
    this.rejectReason,
    this.approvedBy,
    this.approvedAt,
  });

  Map<String, dynamic> toMapForSubmit() {
    return {
      'vehicle': {
        'model': model,
        'plateNumber': plateNumber,
        'color': color,
        'vehicleImageUrl': vehicleImageUrl,
      },
      'license': {
        'licensePdfUrl': licensePdfUrl,
      },
      'insurance': {
        'insurancePdfUrl': insurancePdfUrl,
      },
      'verification': {
        'status': status,
        'rejectReason': rejectReason,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt,
      },
    };
  }

  factory DriverVerificationProfile.fromMap(Map<String, dynamic> map) {
    final vehicle = Map<String, dynamic>.from(map['vehicle'] ?? {});
    final license = Map<String, dynamic>.from(map['license'] ?? {});
    final insurance = Map<String, dynamic>.from(map['insurance'] ?? {});
    final verification = Map<String, dynamic>.from(map['verification'] ?? {});

    return DriverVerificationProfile(
      model: (vehicle['model'] ?? '').toString(),
      plateNumber: (vehicle['plateNumber'] ?? '').toString(),
      color: (vehicle['color'] ?? '').toString(),
      vehicleImageUrl: (vehicle['vehicleImageUrl'] ?? '').toString(),
      licensePdfUrl: (license['licensePdfUrl'] ?? '').toString(),
      insurancePdfUrl: (insurance['insurancePdfUrl'] ?? '').toString(),
      status: (verification['status'] ?? 'not_applied').toString(),
      rejectReason: verification['rejectReason']?.toString(),
      approvedBy: verification['approvedBy']?.toString(),
      approvedAt: verification['approvedAt'] as Timestamp?,
    );
  }
}
