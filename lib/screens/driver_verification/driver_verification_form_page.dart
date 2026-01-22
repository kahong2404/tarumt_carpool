import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/driver_verification_profile.dart';
import '../../repositories/driver_verification_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/driver_verification_storage_service.dart';
import '../../services/pickers/image_picker_service.dart';
import '../../services/pickers/pdf_picker_service.dart';

import '../../utils/administration_verification/app_strings.dart' as dv_s;
import '../../utils/administration_verification/validators.dart' as dv_v;
import '../../utils/administration_verification/app_errors.dart' as dv_err;

import '../../widgets/primary_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/error_list.dart';
import '../../widgets/driver_verification/upload_box.dart';

class DriverVerificationFormPage extends StatefulWidget {
  const DriverVerificationFormPage({super.key});

  @override
  State<DriverVerificationFormPage> createState() =>
      _DriverVerificationFormPageState();
}

class _DriverVerificationFormPageState extends State<DriverVerificationFormPage> {
  static const brandBlue = Color(0xFF1E73FF);

  final _modelCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  final _repo = DriverVerificationRepository();
  final _userRepo = UserRepository();

  final _storage = DriverVerificationStorageService();
  final _imgPicker = ImagePickerService();
  final _pdfPicker = PdfPickerService();

  final _colors = const [
    'Black',
    'White',
    'Silver',
    'Gray',
    'Red',
    'Blue',
    'Green',
    'Yellow',
    'Orange',
    'Brown',
    'Other'
  ];
  String _selectedColor = 'Black';

  // ✅ auto loaded staffId
  String? _staffId;
  bool _loadingStaffId = true;

  // names for UI
  String? _vehicleName;
  String? _licenseName;
  String? _insuranceName;

  // urls after upload (for Open)
  String? _vehicleUrl;
  String? _licenseUrl;
  String? _insuranceUrl;

  bool _submitting = false;

  bool _uploadingVehicle = false;
  bool _uploadingLicense = false;
  bool _uploadingInsurance = false;

  List<String> _errors = [];

  @override
  void initState() {
    super.initState();
    _loadStaffId();
  }

  Future<void> _loadStaffId() async {
    try {
      final staffId = await _userRepo.getStaffIdOfCurrentUser();
      if (!mounted) return;

      if (staffId == null || staffId.trim().isEmpty) {
        setState(() {
          _staffId = null;
          _loadingStaffId = false;
          _errors = ['Missing staffId in user profile.'];
        });
        return;
      }

      setState(() {
        _staffId = staffId.trim();
        _loadingStaffId = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStaffId = false;
        _errors = dv_err.AppErrors.friendlyList(e);
      });
    }
  }

  @override
  void dispose() {
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Open URL
  // -------------------------
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // -------------------------
  // Pick + Upload Vehicle
  // -------------------------
  Future<void> _pickVehicleImage() async {
    if (_staffId == null) return;

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
      setState(() => _errors = [tooLarge]);
      return;
    }

    setState(() {
      _uploadingVehicle = true;
      _errors = [];
      _vehicleName = picked.name;
    });

    try {
      final url = await _storage.uploadVehicleImage(
        staffId: _staffId!,
        bytes: picked.bytes,
      );

      if (!mounted) return;
      setState(() {
        _vehicleUrl = url;
        _uploadingVehicle = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errors = dv_err.AppErrors.friendlyList(e);
        _uploadingVehicle = false;
      });
    }
  }

  // -------------------------
  // Pick + Upload License PDF
  // -------------------------
  Future<void> _pickLicensePdf() async {
    if (_staffId == null) return;

    final file = await _pdfPicker.pickPdfFile();
    if (file == null) return;

    if (!dv_v.Validators.isPdfName(file.name)) {
      setState(() => _errors = [dv_s.AppStrings.pdfOnly]);
      return;
    }

    final bytes = file.bytes;
    if (bytes == null) return;

    final tooLarge = dv_v.Validators.validateFileSize(bytes.length);
    if (tooLarge != null) {
      setState(() => _errors = [tooLarge]);
      return;
    }

    setState(() {
      _uploadingLicense = true;
      _errors = [];
      _licenseName = file.name;
    });

    try {
      final url = await _storage.uploadLicensePdf(
        staffId: _staffId!,
        bytes: bytes,
      );

      if (!mounted) return;
      setState(() {
        _licenseUrl = url;
        _uploadingLicense = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errors = dv_err.AppErrors.friendlyList(e);
        _uploadingLicense = false;
      });
    }
  }

  // -------------------------
  // Pick + Upload Insurance PDF
  // -------------------------
  Future<void> _pickInsurancePdf() async {
    if (_staffId == null) return;

    final file = await _pdfPicker.pickPdfFile();
    if (file == null) return;

    if (!dv_v.Validators.isPdfName(file.name)) {
      setState(() => _errors = [dv_s.AppStrings.pdfOnly]);
      return;
    }

    final bytes = file.bytes;
    if (bytes == null) return;

    final tooLarge = dv_v.Validators.validateFileSize(bytes.length);
    if (tooLarge != null) {
      setState(() => _errors = [tooLarge]);
      return;
    }

    setState(() {
      _uploadingInsurance = true;
      _errors = [];
      _insuranceName = file.name;
    });

    try {
      final url = await _storage.uploadInsurancePdf(
        staffId: _staffId!,
        bytes: bytes,
      );

      if (!mounted) return;
      setState(() {
        _insuranceUrl = url;
        _uploadingInsurance = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errors = dv_err.AppErrors.friendlyList(e);
        _uploadingInsurance = false;
      });
    }
  }

  // -------------------------
  // Submit (Firestore only)
  // -------------------------
  Future<void> _submit() async {
    if (_staffId == null) {
      setState(() => _errors = ['Missing staffId in user profile.']);
      return;
    }

    final errs = dv_v.Validators.validateForm(
      model: _modelCtrl.text,
      plate: _plateCtrl.text,
      color: _selectedColor,
      hasVehicleImage: _vehicleUrl?.isNotEmpty ?? false,
      hasLicensePdf: _licenseUrl?.isNotEmpty ?? false,
      hasInsurancePdf: _insuranceUrl?.isNotEmpty ?? false,
    );

    if (errs.isNotEmpty) {
      setState(() => _errors = errs);
      return;
    }

    if (_uploadingVehicle || _uploadingLicense || _uploadingInsurance) {
      setState(() => _errors = ['Please wait, uploading files...']);
      return;
    }

    setState(() {
      _submitting = true;
      _errors = [];
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final profile = DriverVerificationProfile(
        model: _modelCtrl.text.trim(),
        plateNumber: _plateCtrl.text.trim(),
        color: _selectedColor,
        vehicleImageUrl: _vehicleUrl!,
        licensePdfUrl: _licenseUrl!,
        insurancePdfUrl: _insuranceUrl!,
        status: 'pending',
        rejectReason: null,
        approvedBy: null,
        approvedAt: null,
      );

      await _repo.submit(
        uid: uid,
        staffId: _staffId!,
        profile: profile,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitted. Please wait for admin review.')),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => _errors = dv_err.AppErrors.friendlyList(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    if (_loadingStaffId) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F6FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final staffId = _staffId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        title: const Text('Driver Verification'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              staffId == null ? 'Staff ID: -' : 'Staff ID: $staffId',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),

            ErrorList(_errors),
            if (_errors.isNotEmpty) const SizedBox(height: 12),

            PrimaryTextField(controller: _modelCtrl, label: 'Vehicle Model'),
            const SizedBox(height: 12),

            PrimaryTextField(controller: _plateCtrl, label: 'Plate Number'),
            const SizedBox(height: 12),

            // Color dropdown
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedColor,
                  isExpanded: true,
                  items: _colors
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedColor = v);
                  },
                ),
              ),
            ),

            const SizedBox(height: 14),

            UploadBox(
              title: 'Vehicle Image',
              hint: 'JPG/PNG (max 5MB)',
              fileName: _vehicleName,
              fileUrl: _vehicleUrl,
              selected: _vehicleUrl?.isNotEmpty ?? false,
              uploading: _uploadingVehicle,
              onPick: _pickVehicleImage,
              onOpen: (_vehicleUrl?.isNotEmpty ?? false)
                  ? () => _openUrl(_vehicleUrl!)
                  : null,
              showImagePreview: true,
            ),

            const SizedBox(height: 12),

            UploadBox(
              title: 'Driving License (PDF)',
              hint: 'PDF only (max 5MB)',
              fileName: _licenseName,
              fileUrl: _licenseUrl,
              selected: _licenseUrl?.isNotEmpty ?? false,
              uploading: _uploadingLicense,
              onPick: _pickLicensePdf,
              onOpen: (_licenseUrl?.isNotEmpty ?? false)
                  ? () => _openUrl(_licenseUrl!)
                  : null,
              showPdfIcon: true,
            ),

            const SizedBox(height: 12),

            UploadBox(
              title: 'Car Insurance (PDF)',
              hint: 'PDF only (max 5MB)',
              fileName: _insuranceName,
              fileUrl: _insuranceUrl,
              selected: _insuranceUrl?.isNotEmpty ?? false,
              uploading: _uploadingInsurance,
              onPick: _pickInsurancePdf,
              onOpen: (_insuranceUrl?.isNotEmpty ?? false)
                  ? () => _openUrl(_insuranceUrl!)
                  : null,
              showPdfIcon: true,
            ),

            const SizedBox(height: 18),

            PrimaryButton(
              text: 'Submit for Review',
              loading: _submitting,
              onPressed: (_submitting || staffId == null) ? null : _submit,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
