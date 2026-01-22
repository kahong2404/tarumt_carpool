import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../repositories/driver_verification_repository.dart';
import '../../repositories/user_repository.dart';

import '../../widgets/driver_verification/vehicle_and_driver_status_card.dart';
import '../../widgets/driver_verification/status_button.dart';
import '../../widgets/driver_verification/dv_info_card.dart';
import '../../widgets/driver_verification/dv_files_card.dart';
import '../../widgets/driver_verification/dv_reject_card.dart';

import 'driver_verification_form_page.dart';

class DriverVerificationCenterPage extends StatelessWidget {
  const DriverVerificationCenterPage({super.key});

  static const brandBlue = Color(0xFF1E73FF);

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
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
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final userRepo = UserRepository();
    final dvRepo = DriverVerificationRepository();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        title: const Text('Driver Verification'),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: userRepo.streamUserDoc(uid),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = userSnap.data!;
          final staffId = (user['staffId'] ?? '').toString().trim();

          if (staffId.isEmpty) {
            return const Center(child: Text('Missing staffId in user profile.'));
          }

          return StreamBuilder<Map<String, dynamic>?>(
            stream: dvRepo.streamMyVerificationByStaffId(staffId),
            builder: (context, dvSnap) {
              if (dvSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (dvSnap.hasError) {
                return Center(child: Text('Error: ${dvSnap.error}'));
              }

              final data = dvSnap.data; // can be null

              // defaults
              String status = 'not_applied';
              String vehicleModel = 'No vehicle submitted';
              String plate = '-';
              String color = '-';

              String? vehicleUrl;
              String? licenseUrl;
              String? insuranceUrl;
              String? rejectReason;

              if (data != null) {
                final vehicle = (data['vehicle'] ?? {}) as Map<String, dynamic>;
                final verification =
                (data['verification'] ?? {}) as Map<String, dynamic>;
                final license = (data['license'] ?? {}) as Map<String, dynamic>;
                final insurance =
                (data['insurance'] ?? {}) as Map<String, dynamic>;

                vehicleModel = (vehicle['model'] ?? 'No vehicle submitted').toString();
                plate = (vehicle['plateNumber'] ?? '-').toString();
                color = (vehicle['color'] ?? '-').toString();

                vehicleUrl = vehicle['vehicleImageUrl']?.toString();
                licenseUrl = license['licensePdfUrl']?.toString();
                insuranceUrl = insurance['insurancePdfUrl']?.toString();

                status = (verification['status'] ?? 'not_applied').toString();
                rejectReason = verification['rejectReason']?.toString();
              }

              final action = _actionConfig(status);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  VehicleAndDriverStatusCard(
                    vehicleModel: vehicleModel,
                    status: status,
                  ),
                  const SizedBox(height: 12),

                  DvInfoCard(
                    title: 'Submitted Details',
                    rows: [
                      DvInfoRow(label: 'Vehicle Model', value: vehicleModel),
                      DvInfoRow(label: 'Plate Number', value: plate),
                      DvInfoRow(label: 'Color', value: color),
                    ],
                  ),
                  const SizedBox(height: 12),

                  DvFilesCard(
                    vehicleUrl: vehicleUrl,
                    licenseUrl: licenseUrl,
                    insuranceUrl: insuranceUrl,
                    onOpen: _openUrl,
                  ),

                  if (status == 'rejected' &&
                      rejectReason != null &&
                      rejectReason.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DvRejectCard(reason: rejectReason.trim()),
                  ],

                  const SizedBox(height: 18),

                  StatusButton(
                    status: status,
                    text: action.text,
                    onPressed: action.enabled
                        ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => DriverVerificationFormPage()                        ),
                      );
                    }
                        : null,
                  ),

                  const SizedBox(height: 10),
                  Text(
                    (status == 'not_applied' || status == 'rejected')
                        ? 'You can edit and submit your verification.'
                        : 'Your verification is locked while pending/approved.',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              );
            },
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
