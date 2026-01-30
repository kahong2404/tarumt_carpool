import '../../../models/driver_verification_profile.dart';

class DriverVerificationViewData {
  final String status; // not_applied | pending | approved | rejected

  final String vehicleModel;
  final String plate;
  final String color;

  final String? vehicleUrl;
  final String? licenseUrl;
  final String? insuranceUrl;

  // ✅ matches Firestore: verification.rejectReason
  final String? rejectReason;

  DriverVerificationViewData({
    required this.status,
    required this.vehicleModel,
    required this.plate,
    required this.color,
    required this.vehicleUrl,
    required this.licenseUrl,
    required this.insuranceUrl,
    required this.rejectReason,
  });

  factory DriverVerificationViewData.empty() {
    return DriverVerificationViewData(
      status: 'not_applied',
      vehicleModel: 'No vehicle submitted',
      plate: '-',
      color: '-',
      vehicleUrl: null,
      licenseUrl: null,
      insuranceUrl: null,
      rejectReason: null,
    );
  }

  factory DriverVerificationViewData.fromDoc(Map<String, dynamic> doc) {
    final p = DriverVerificationProfile.fromMap(doc);

    String? cleanUrl(String s) {
      final t = s.trim();
      return t.isEmpty ? null : t;
    }

    final reason = (p.rejectReason ?? '').trim();

    return DriverVerificationViewData(
      status: p.status,
      vehicleModel: p.vehicleModel.trim().isEmpty ? 'No vehicle submitted' : p.vehicleModel.trim(),
      plate: p.plateNumber.trim().isEmpty ? '-' : p.plateNumber.trim(),
      color: p.color.trim().isEmpty ? '-' : p.color.trim(),
      vehicleUrl: cleanUrl(p.vehicleImageUrl),
      licenseUrl: cleanUrl(p.licensePdfUrl),
      insuranceUrl: cleanUrl(p.insurancePdfUrl),
      rejectReason: reason.isEmpty ? null : reason,
    );
  }
}
