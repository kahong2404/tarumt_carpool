class DriverVerificationViewData {
  final String status; // not_applied | pending | approved | rejected
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
    this.vehicleUrl,
    this.licenseUrl,
    this.insuranceUrl,
    this.rejectReason,
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

  factory DriverVerificationViewData.fromDoc(Map<String, dynamic> data) {
    final vehicle = Map<String, dynamic>.from(data['vehicle'] ?? {});
    final license = Map<String, dynamic>.from(data['license'] ?? {});
    final insurance = Map<String, dynamic>.from(data['insurance'] ?? {});
    final verification = Map<String, dynamic>.from(data['verification'] ?? {});

    return DriverVerificationViewData(
      vehicleModel: (vehicle['model'] ?? 'No vehicle submitted').toString(),
      plate: (vehicle['plateNumber'] ?? '-').toString(),
      color: (vehicle['color'] ?? '-').toString(),
      vehicleUrl: vehicle['vehicleImageUrl']?.toString(),
      licenseUrl: license['licensePdfUrl']?.toString(),
      insuranceUrl: insurance['insurancePdfUrl']?.toString(),
      status: (verification['status'] ?? 'not_applied').toString(),
      rejectReason: verification['rejectReason']?.toString(),
    );
  }
}
