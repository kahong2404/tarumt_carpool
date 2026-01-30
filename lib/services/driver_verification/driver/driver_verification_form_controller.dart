import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/driver_verification_profile.dart';
import '../../../repositories/driver_verification_repository.dart';

import '../../../utils/administration_verification/app_errors.dart';
import '../../../utils/administration_verification/app_strings.dart';
import '../../../utils/administration_verification/validators.dart';

import 'driver_verification_service.dart';
import 'driver_verification_storage_service.dart';

import '../../pickers/image_picker_service.dart';
import '../../pickers/pdf_picker_service.dart';

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
  final DriverVerificationRepository _repo;

  DriverVerificationFormController({
    DriverVerificationService? svc,
    DriverVerificationStorageService? storage,
    ImagePickerService? imgPicker,
    PdfPickerService? pdfPicker,
    DriverVerificationRepository? repo,
  })  : _svc = svc ?? DriverVerificationService(),
        _storage = storage ?? DriverVerificationStorageService(),
        _imgPicker = imgPicker ?? ImagePickerService(),
        _pdfPicker = pdfPicker ?? PdfPickerService(),
        _repo = repo ?? DriverVerificationRepository();

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
        errors: AppErrors.friendlyList(e),
      );
      notifyListeners();
    }
  }

  /// ✅ Prefill uploads when reapply (optional)
  void prefillFromExisting(Map<String, dynamic> doc) {
    final p = DriverVerificationProfile.fromMap(doc);

    state = state.copyWith(
      vehicleUrl: p.vehicleImageUrl.trim().isEmpty ? null : p.vehicleImageUrl.trim(),
      licenseUrl: p.licensePdfUrl.trim().isEmpty ? null : p.licensePdfUrl.trim(),
      insuranceUrl: p.insurancePdfUrl.trim().isEmpty ? null : p.insurancePdfUrl.trim(),
      vehicleName: p.vehicleImageUrl.trim().isEmpty ? null : 'Existing uploaded image',
      licenseName: p.licensePdfUrl.trim().isEmpty ? null : 'Existing uploaded PDF',
      insuranceName: p.insurancePdfUrl.trim().isEmpty ? null : 'Existing uploaded PDF',
      errors: [],
    );
    notifyListeners();
  }

  Future<void> pickVehicleImage(BuildContext context) async {
    if (state.staffId == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
        ]),
      ),
    );
    if (source == null) return;

    final picked = await _imgPicker.pickVehicleImage(source: source);
    if (picked == null) return;

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

      state = state.copyWith(vehicleUrl: url, uploadingVehicle: false);
      notifyListeners();
    } catch (e) {
      state = state.copyWith(uploadingVehicle: false, errors: AppErrors.friendlyList(e));
      notifyListeners();
    }
  }

  Future<void> pickLicensePdf() async {
    if (state.staffId == null) return;

    final file = await _pdfPicker.pickPdfFile();
    if (file == null) return;

    final bytes = file.bytes;
    if (bytes == null) {
      state = state.copyWith(errors: [AppStrings.pdfOnly]);
      notifyListeners();
      return;
    }

    final sizeErr = Validators.validateFileSize(bytes.length);
    if (sizeErr != null) {
      state = state.copyWith(errors: [sizeErr]);
      notifyListeners();
      return;
    }

    state = state.copyWith(uploadingLicense: true, licenseName: file.name, errors: []);
    notifyListeners();

    try {
      final url = await _storage.uploadLicensePdf(
        staffId: state.staffId!,
        bytes: bytes,
      );
      state = state.copyWith(licenseUrl: url, uploadingLicense: false);
      notifyListeners();
    } catch (e) {
      state = state.copyWith(uploadingLicense: false, errors: AppErrors.friendlyList(e));
      notifyListeners();
    }
  }

  Future<void> pickInsurancePdf() async {
    if (state.staffId == null) return;

    final file = await _pdfPicker.pickPdfFile();
    if (file == null) return;

    final bytes = file.bytes;
    if (bytes == null) {
      state = state.copyWith(errors: [AppStrings.pdfOnly]);
      notifyListeners();
      return;
    }

    final sizeErr = Validators.validateFileSize(bytes.length);
    if (sizeErr != null) {
      state = state.copyWith(errors: [sizeErr]);
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
      state = state.copyWith(insuranceUrl: url, uploadingInsurance: false);
      notifyListeners();
    } catch (e) {
      state = state.copyWith(uploadingInsurance: false, errors: AppErrors.friendlyList(e));
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
    if (!canSubmit) {
      state = state.copyWith(errors: [AppStrings.genericError]);
      notifyListeners();
      return;
    }

    final errors = Validators.validateForm(
      model: model,
      plate: plate,
      color: color,
      hasVehicleImage: (state.vehicleUrl ?? '').trim().isNotEmpty,
      hasLicensePdf: (state.licenseUrl ?? '').trim().isNotEmpty,
      hasInsurancePdf: (state.insuranceUrl ?? '').trim().isNotEmpty,
    );

    if (errors.isNotEmpty) {
      state = state.copyWith(errors: errors);
      notifyListeners();
      return;
    }

    state = state.copyWith(submitting: true, errors: []);
    notifyListeners();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not signed in.');

      final staffId = state.staffId!;
      final profile = DriverVerificationProfile(
        vehicleModel: model.trim(),
        plateNumber: plate.trim(),
        color: color.trim(),
        vehicleImageUrl: state.vehicleUrl!,
        licensePdfUrl: state.licenseUrl!,
        insurancePdfUrl: state.insuranceUrl!,
        status: 'pending',
      );

      await _repo.submitPending(
        uid: uid,
        staffId: staffId,
        profile: profile,
      );

      state = state.copyWith(submitting: false);
      notifyListeners();
    } catch (e) {
      state = state.copyWith(
        submitting: false,
        errors: AppErrors.friendlyList(e),
      );
      notifyListeners();
    }
  }
}
