import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/driver_verification/driver/driver_verification_service.dart';
import '../../../services/driver_verification/driver/driver_verification_mapper.dart';

import '../../../widgets/driver_verification/vehicle_and_driver_status_card.dart';
import '../../../widgets/driver_verification/status_button.dart';
import '../../../widgets/driver_verification/dv_info_card.dart';
import '../../../widgets/driver_verification/dv_files_card.dart';
import '../../../widgets/driver_verification/dv_reject_card.dart';

import 'driver_verification_form_page.dart';

class DriverVerificationCenterPage extends StatelessWidget {
  DriverVerificationCenterPage({super.key});

  static const brandBlue = Color(0xFF1E73FF);

  // ✅ service created once
  final DriverVerificationService _svc = DriverVerificationService();

  Future<void> _openUrl(String url) async {
    if (url.trim().isEmpty) return;
    final uri = Uri.parse(url);

    // Optional: guard against invalid URLs
    if (!await canLaunchUrl(uri)) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  _ActionConfig _actionConfig(String status) {
    switch (status) {
      case 'pending':
        return const _ActionConfig(
          text: 'Submitted (Pending Review)',
          enabled: false,
        );
      case 'approved':
        return const _ActionConfig(
          text: 'Verified',
          enabled: false,
        );
      case 'rejected':
        return const _ActionConfig(
          text: 'Reapply for Driver Verification',
          enabled: true,
        );
      default:
        return const _ActionConfig(
          text: 'Apply for Driver Verification',
          enabled: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        title: const Text('Driver Verification'),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _svc.streamMyVerification(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final view = (snap.data == null)
              ? DriverVerificationViewData.empty()
              : DriverVerificationViewData.fromDoc(snap.data!);

          final action = _actionConfig(view.status);

          // ✅ FIX: SafeArea prevents bottom content being hidden
          return SafeArea(
            bottom: true,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                VehicleAndDriverStatusCard(
                  vehicleModel: view.vehicleModel,
                  status: view.status,
                ),
                const SizedBox(height: 12),

                DvInfoCard(
                  title: 'Submitted Details',
                  rows: [
                    DvInfoRow(label: 'Vehicle Model', value: view.vehicleModel),
                    DvInfoRow(label: 'Plate Number', value: view.plate),
                    DvInfoRow(label: 'Color', value: view.color),
                  ],
                ),
                const SizedBox(height: 12),

                DvFilesCard(
                  vehicleUrl: view.vehicleUrl,
                  licenseUrl: view.licenseUrl,
                  insuranceUrl: view.insuranceUrl,
                  onOpen: _openUrl,
                ),

                if (view.status == 'rejected' &&
                    (view.rejectReason ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DvRejectCard(reason: view.rejectReason!.trim()),
                ],

                const SizedBox(height: 18),

                StatusButton(
                  status: view.status,
                  text: action.text,
                  onPressed: action.enabled
                      ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DriverVerificationFormPage(),
                      ),
                    );
                  }
                      : null,
                ),

                const SizedBox(height: 10),
                Text(
                  (view.status == 'not_applied' || view.status == 'rejected')
                      ? 'You can edit and submit your verification.'
                      : 'Your verification is locked while pending/approved.',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActionConfig {
  final String text;
  final bool enabled;
  const _ActionConfig({required this.text, required this.enabled});
}
