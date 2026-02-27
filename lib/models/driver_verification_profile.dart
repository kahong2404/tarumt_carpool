import 'package:cloud_firestore/cloud_firestore.dart';

class DriverVerificationProfile {
  final String vehicleModel;
  final String plateNumber;
  final String color;
  final String vehicleImageUrl;
  final String licensePdfUrl;
  final String insurancePdfUrl;
  final String status;  // not_applied | pending | approved | rejected
  final String? rejectReason;   /// reject reason for CURRENT rejected state
  final String? lastRejectReason;  ///  keep the latest reject reason even after reapply (pending)
  final String? reviewedBy;
  final Timestamp? reviewedAt;
  final String? approvedBy;
  final Timestamp? approvedAt;

  const DriverVerificationProfile({
    required this.vehicleModel,
    required this.plateNumber,
    required this.color,
    required this.vehicleImageUrl,
    required this.licensePdfUrl,
    required this.insurancePdfUrl,
    required this.status,
    this.rejectReason,
    this.lastRejectReason,
    this.reviewedBy,
    this.reviewedAt,
    this.approvedBy,
    this.approvedAt,
  });

  /// For submit/reapply:
  /// - sets status pending
  /// - clears current reject/approval info
  /// - DO NOT delete lastRejectReason here
  /// Convert Dart object → Firestore Map
  Map<String, dynamic> toMapForSubmitPending() {
    return {
      'vehicle': {
        'model': vehicleModel.trim(),
        'plateNumber': plateNumber.trim(),
        'color': color.trim(),
        'vehicleImageUrl': vehicleImageUrl.trim(),
      },
      'license': {
        'licensePdfUrl': licensePdfUrl.trim(),
      },
      'insurance': {
        'insurancePdfUrl': insurancePdfUrl.trim(),
      },
      'verification': {
        'status': 'pending',
        'rejectReason': FieldValue.delete(),         // clear current rejection result, but didnt change the las reject reason
        'reviewedBy': FieldValue.delete(),
        'reviewedAt': FieldValue.delete(),
        'approvedBy': FieldValue.delete(),         // clear approval result
        'approvedAt': FieldValue.delete(),
      },
    };
  }
//Used to convert Firestore data → Dart model
  factory DriverVerificationProfile.fromMap(Map<String, dynamic> map) {
    final vehicle = Map<String, dynamic>.from(map['vehicle'] ?? {});
    final license = Map<String, dynamic>.from(map['license'] ?? {});
    final insurance = Map<String, dynamic>.from(map['insurance'] ?? {});
    final ver = Map<String, dynamic>.from(map['verification'] ?? {});
//Meaning of to String:
//If value exists → convert it to String
// If value is null → return null
    return DriverVerificationProfile(
      vehicleModel: (vehicle['model'] ?? '').toString(),
      plateNumber: (vehicle['plateNumber'] ?? '').toString(),
      color: (vehicle['color'] ?? '').toString(),
      vehicleImageUrl: (vehicle['vehicleImageUrl'] ?? '').toString(),
      licensePdfUrl: (license['licensePdfUrl'] ?? '').toString(),
      insurancePdfUrl: (insurance['insurancePdfUrl'] ?? '').toString(),
      status: (ver['status'] ?? 'not_applied').toString(),
      rejectReason: ver['rejectReason']?.toString(),
      lastRejectReason: ver['lastRejectReason']?.toString(),
      reviewedBy: ver['reviewedBy']?.toString(),
      reviewedAt: ver['reviewedAt'] as Timestamp?,
      approvedBy: ver['approvedBy']?.toString(),
      approvedAt: ver['approvedAt'] as Timestamp?,  //can be null
    );
  }
//Driver has never submitted anything

}
