import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/driver_verification_profile.dart';
import 'driver_verification_storage_service.dart';
import 'driver_verification_service.dart';
import '../../../services/pickers/image_picker_service.dart';
import '../../../services/pickers/pdf_picker_service.dart';

import '../../../utils/administration_verification/app_strings.dart' as dv_s;
import '../../../utils/administration_verification/validators.dart' as dv_v;
import '../../../utils/administration_verification/app_errors.dart' as dv_err;

class DriverVerificationFormState {
  final bool loadingStaffId;
  final String? staffId;

  final bool submitting;

  final bool uploadingVehicle;
  final bool uploadingLicense;
  final bool uploadingInsurance;

  final String? vehicleName;
  final String? licenseName;
  final String? insuranceName;

  final String? vehicleUrl;
  final String? licenseUrl;
  final String? insuranceUrl;

  final List<String> errors;

  const DriverVerificationFormState({
    required this.loadingStaffId,
    required this.staffId,
    required this.submitting,
    required this.uploadingVehicle,
    required this.uploadingLicense,
    required this.uploadingInsurance,
    required this.vehicleName,
    required this.licenseName,
    required this.insuranceName,
    required this.vehicleUrl,
    required this.licenseUrl,
    required this.insuranceUrl,
    required this.errors,
  });

  factory DriverVerificationFormState.initial() {
    return const DriverVerificationFormState(
      loadingStaffId: true,
      staffId: null,
      submitting: false,
      uploadingVehicle: false,
      uploadingLicense: false,
      uploadingInsurance: false,
      vehicleName: null,
      licenseName: null,
      insuranceName: null,
      vehicleUrl: null,
      licenseUrl: null,
      insuranceUrl: null,
      errors: [],
    );
  }

  DriverVerificationFormState copyWith({
    bool? loadingStaffId,
    String? staffId,
    bool? submitting,
    bool? uploadingVehicle,
    bool? uploadingLicense,
    bool? uploadingInsurance,
    String? vehicleName,
    String? licenseName,
    String? insuranceName,
    String? vehicleUrl,
    String? licenseUrl,
    String? insuranceUrl,
    List<String>? errors,
  }) {
    return DriverVerificationFormState(
      loadingStaffId: loadingStaffId ?? this.loadingStaffId,
      staffId: staffId ?? this.staffId,
      submitting: submitting ?? this.submitting,
      uploadingVehicle: uploadingVehicle ?? this.uploadingVehicle,
      uploadingLicense: uploadingLicense ?? this.uploadingLicense,
      uploadingInsurance: uploadingInsurance ?? this.uploadingInsurance,
      vehicleName: vehicleName ?? this.vehicleName,
      licenseName: licenseName ?? this.licenseName,
      insuranceName: insuranceName ?? this.insuranceName,
      vehicleUrl: vehicleUrl ?? this.vehicleUrl,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      insuranceUrl: insuranceUrl ?? this.insuranceUrl,
      errors: errors ?? this.errors,
    );
  }
}

class DriverVerificationFormController extends ChangeNotifier {
  DriverVerificationFormState state = DriverVerificationFormState.initial();

  final DriverVerificationService _svc;
  final DriverVerificationStorageService _storage;
  final ImagePickerService _imgPicker;
  final PdfPickerService _pdfPicker;

  DriverVerificationFormController({
    DriverVerificationService? svc,
    DriverVerificationStorageService? storage,
    ImagePickerService? imgPicker,
    PdfPickerService? pdfPicker,
  })  : _svc = svc ?? DriverVerificationService(),
        _storage = storage ?? DriverVerificationStorageService(),
        _imgPicker = imgPicker ?? ImagePickerService(),
        _pdfPicker = pdfPicker ?? PdfPickerService();

  Future<void> init() async {
    try {
      final staffId = await _svc.getMyStaffIdOrThrow();
      state = state.copyWith(
        staffId: staffId,
        loadingStaffId: false,
        errors: [],
      );
      notifyListeners();
    } catch (e) {
      state = state.copyWith(
        loadingStaffId: false,
        errors: dv_err.AppErrors.friendlyList(e),
      );
      notifyListeners();
    }
  }

  Future<void> pickVehicleImage(BuildContext context) async {
    if (state.staffId == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _imgPicker.pickVehicleImage(source: source);
    if (picked == null) return;

    final tooLarge = dv_v.Validators.validateFileSize(picked.sizeBytes);
    if (tooLarge != null) {
      state = state.copyWith(errors: [tooLarge]);
      notifyListeners();
      return;
    }

    state = state.copyWith(
      uploadingVehicle: true,
      vehicleName: picked.name,
      errors: [],
    );
    notifyListeners();

    try {
      final lower = picked.name.toLowerCase();
      final contentType = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';

      final url = await _storage.uploadVehicleImage(
        staffId: state.staffId!,
        bytes: picked.bytes,
        contentType: contentType,
      );

      state = state.copyWith(
        vehicleUrl: url,
        uploadingVehicle: false,
      );
      notifyListeners();
    } catch (e) {
      state = state.copyWith(
        uploadingVehicle: false,
        errors: dv_err.AppErrors.friendlyList(e),
      );
      notifyListeners();
    }
  }

  Future<void> pickLicensePdf() async {
    if (state.staffId == null) return;

    final file = await _pdfPicker.pickPdfFile();
    if (file == null) return;

    if (!dv_v.Validators.isPdfName(file.name)) {
      state = state.copyWith(errors: [dv_s.AppStrings.pdfOnly]);
      notifyListeners();
      return;
    }

    final bytes = file.bytes;
    if (bytes == null) {
      state = state.copyWith(errors: ['Failed to read PDF bytes. Please try again.']);
      notifyListeners();
      return;
    }

    final tooLarge = dv_v.Validators.validateFileSize(bytes.length);
    if (tooLarge != null) {
      state = state.copyWith(errors: [tooLarge]);
      notifyListeners();
      return;
    }

    state = state.copyWith(
      uploadingLicense: true,
      licenseName: file.name,
      errors: [],
    );
    notifyListeners();

    try {
      final url = await _storage.uploadLicensePdf(
        staffId: state.staffId!,
        bytes: bytes,
      );

      state = state.copyWith(
        licenseUrl: url,
        uploadingLicense: false,
      );
      notifyListeners();
    } catch (e) {
      state = state.copyWith(
        uploadingLicense: false,
        errors: dv_err.AppErrors.friendlyList(e),
      );
      notifyListeners();
    }
  }

  Future<void> pickInsurancePdf() async {
    if (state.staffId == null) return;

    final file = await _pdfPicker.pickPdfFile();
    if (file == null) return;

    if (!dv_v.Validators.isPdfName(file.name)) {
      state = state.copyWith(errors: [dv_s.AppStrings.pdfOnly]);
      notifyListeners();
      return;
    }

    final bytes = file.bytes;
    if (bytes == null) {
      state = state.copyWith(errors: ['Failed to read PDF bytes. Please try again.']);
      notifyListeners();
      return;
    }

    final tooLarge = dv_v.Validators.validateFileSize(bytes.length);
    if (tooLarge != null) {
      state = state.copyWith(errors: [tooLarge]);
      notifyListeners();
      return;
    }

    state = state.copyWith(
      uploadingInsurance: true,
      insuranceName: file.name,
      errors: [],
    );
    notifyListeners();

    try {
      final url = await _storage.uploadInsurancePdf(
        staffId: state.staffId!,
        bytes: bytes,
      );

      state = state.copyWith(
        insuranceUrl: url,
        uploadingInsurance: false,
      );
      notifyListeners();
    } catch (e) {
      state = state.copyWith(
        uploadingInsurance: false,
        errors: dv_err.AppErrors.friendlyList(e),
      );
      notifyListeners();
    }
  }

  bool get canSubmit =>
      !state.submitting &&
          state.staffId != null &&
          !state.uploadingVehicle &&
          !state.uploadingLicense &&
          !state.uploadingInsurance;

  Future<void> submit({
    required String model,
    required String plate,
    required String color,
  }) async {
    if (state.staffId == null) {
      state = state.copyWith(errors: ['Missing staffId in user profile.']);
      notifyListeners();
      return;
    }

    final errs = dv_v.Validators.validateForm(
      model: model,
      plate: plate,
      color: color,
      hasVehicleImage: state.vehicleUrl?.isNotEmpty ?? false,
      hasLicensePdf: state.licenseUrl?.isNotEmpty ?? false,
      hasInsurancePdf: state.insuranceUrl?.isNotEmpty ?? false,
    );

    if (errs.isNotEmpty) {
      state = state.copyWith(errors: errs);
      notifyListeners();
      return;
    }

    if (!canSubmit) {
      state = state.copyWith(errors: ['Please wait, uploading files...']);
      notifyListeners();
      return;
    }

    state = state.copyWith(submitting: true, errors: []);
    notifyListeners();

    try {
      final profile = DriverVerificationProfile(
        model: model.trim(),
        plateNumber: plate.trim(),
        color: color,
        vehicleImageUrl: state.vehicleUrl!,
        licensePdfUrl: state.licenseUrl!,
        insurancePdfUrl: state.insuranceUrl!,
        status: 'pending',
        rejectReason: null,
        approvedBy: null,
        approvedAt: null,
      );

      await _svc.submitPending(profile: profile);

      state = state.copyWith(submitting: false);
      notifyListeners();
    } catch (e) {
      state = state.copyWith(
        submitting: false,
        errors: dv_err.AppErrors.friendlyList(e),
      );
      notifyListeners();
    }
  }
}
