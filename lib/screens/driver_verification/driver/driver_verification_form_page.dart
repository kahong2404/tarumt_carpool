import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../widgets/primary_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/error_list.dart';
import '../../../widgets/driver_verification/upload_box.dart';

import '../../../services/driver_verification/driver/driver_verification_form_controller.dart';

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

  final _colors = const [
    'Black','White','Silver','Gray','Red','Blue','Green','Yellow','Orange','Brown','Other'
  ];
  String _selectedColor = 'Black';

  late final DriverVerificationFormController controller;

  @override
  void initState() {
    super.initState();
    controller = DriverVerificationFormController()..addListener(_onUpdate);
    controller.init();
  }

  void _onUpdate() => setState(() {});

  @override
  void dispose() {
    controller.removeListener(_onUpdate);
    controller.dispose();
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = controller.state;

    if (s.loadingStaffId) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F6FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final disableSubmit = !controller.canSubmit;

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
              s.staffId == null ? 'Staff ID: -' : 'Staff ID: ${s.staffId}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),

            ErrorList(s.errors),
            if (s.errors.isNotEmpty) const SizedBox(height: 12),

            PrimaryTextField(controller: _modelCtrl, label: 'Vehicle Model'),
            const SizedBox(height: 12),

            PrimaryTextField(controller: _plateCtrl, label: 'Plate Number'),
            const SizedBox(height: 12),

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
              fileName: s.vehicleName,
              fileUrl: s.vehicleUrl,
              selected: s.vehicleUrl?.isNotEmpty ?? false,
              uploading: s.uploadingVehicle,
              onPick: () => controller.pickVehicleImage(context),
              onOpen: (s.vehicleUrl?.isNotEmpty ?? false)
                  ? () => _openUrl(s.vehicleUrl!)
                  : null,
              showImagePreview: true,
            ),

            const SizedBox(height: 12),

            UploadBox(
              title: 'Driving License (PDF)',
              hint: 'PDF only (max 5MB)',
              fileName: s.licenseName,
              fileUrl: s.licenseUrl,
              selected: s.licenseUrl?.isNotEmpty ?? false,
              uploading: s.uploadingLicense,
              onPick: controller.pickLicensePdf,
              onOpen: (s.licenseUrl?.isNotEmpty ?? false)
                  ? () => _openUrl(s.licenseUrl!)
                  : null,
              showPdfIcon: true,
            ),

            const SizedBox(height: 12),

            UploadBox(
              title: 'Car Insurance (PDF)',
              hint: 'PDF only (max 5MB)',
              fileName: s.insuranceName,
              fileUrl: s.insuranceUrl,
              selected: s.insuranceUrl?.isNotEmpty ?? false,
              uploading: s.uploadingInsurance,
              onPick: controller.pickInsurancePdf,
              onOpen: (s.insuranceUrl?.isNotEmpty ?? false)
                  ? () => _openUrl(s.insuranceUrl!)
                  : null,
              showPdfIcon: true,
            ),

            const SizedBox(height: 18),

            PrimaryButton(
              text: 'Submit for Review',
              loading: s.submitting,
              onPressed: disableSubmit
                  ? null
                  : () async {
                await controller.submit(
                  model: _modelCtrl.text,
                  plate: _plateCtrl.text,
                  color: _selectedColor,
                );

                // If submit succeeded (no errors + not submitting), pop
                if (mounted && controller.state.errors.isEmpty && !controller.state.submitting) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Submitted. Please wait for admin review.')),
                  );
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
