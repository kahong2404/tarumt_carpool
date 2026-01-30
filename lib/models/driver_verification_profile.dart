import 'package:cloud_firestore/cloud_firestore.dart';

class DriverVerificationProfile {
  final String vehicleModel;
  final String plateNumber;
  final String color;

  final String vehicleImageUrl;
  final String licensePdfUrl;
  final String insurancePdfUrl;

  // not_applied | pending | approved | rejected
  final String status;

  /// reject reason for CURRENT rejected state
  final String? rejectReason;

  /// ✅ keep the latest reject reason even after reapply (pending)
  final String? lastRejectReason;

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

        // clear current rejection result
        'rejectReason': FieldValue.delete(),
        'reviewedBy': FieldValue.delete(),
        'reviewedAt': FieldValue.delete(),

        // clear approval result
        'approvedBy': FieldValue.delete(),
        'approvedAt': FieldValue.delete(),

        // ✅ keep lastRejectReason (do nothing)
      },
    };
  }

  factory DriverVerificationProfile.fromMap(Map<String, dynamic> map) {
    final vehicle = Map<String, dynamic>.from(map['vehicle'] ?? {});
    final license = Map<String, dynamic>.from(map['license'] ?? {});
    final insurance = Map<String, dynamic>.from(map['insurance'] ?? {});
    final ver = Map<String, dynamic>.from(map['verification'] ?? {});

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
      approvedAt: ver['approvedAt'] as Timestamp?,
    );
  }

  static DriverVerificationProfile empty() {
    return const DriverVerificationProfile(
      vehicleModel: 'No vehicle submitted',
      plateNumber: '-',
      color: '-',
      vehicleImageUrl: '',
      licensePdfUrl: '',
      insurancePdfUrl: '',
      status: 'not_applied',
    );
  }
}
