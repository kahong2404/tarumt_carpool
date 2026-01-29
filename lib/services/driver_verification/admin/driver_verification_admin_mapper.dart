import '../../../models/driver_verification_profile.dart';

class DriverVerificationViewData {
  final String status;
  final String vehicleModel;
  final String plate;
  final String color;

  final String? vehicleUrl;
  final String? licenseUrl;
  final String? insuranceUrl;

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

  factory DriverVerificationViewData.fromDoc(Map<String, dynamic> doc) {
    final profile = DriverVerificationProfile.fromMap(doc);

    return DriverVerificationViewData(
      status: profile.status,
      vehicleModel: profile.model.isEmpty ? '-' : profile.model,
      plate: profile.plateNumber.isEmpty ? '-' : profile.plateNumber,
      color: profile.color.isEmpty ? '-' : profile.color,
      vehicleUrl: profile.vehicleImageUrl.isEmpty ? null : profile.vehicleImageUrl,
      licenseUrl: profile.licensePdfUrl.isEmpty ? null : profile.licensePdfUrl,
      insuranceUrl: profile.insurancePdfUrl.isEmpty ? null : profile.insurancePdfUrl,
      rejectReason: profile.rejectReason,
    );
  }

  static DriverVerificationViewData empty() => DriverVerificationViewData(
    status: 'not_applied',
    vehicleModel: '-',
    plate: '-',
    color: '-',
    vehicleUrl: null,
    licenseUrl: null,
    insuranceUrl: null,
    rejectReason: null,
  );
}
