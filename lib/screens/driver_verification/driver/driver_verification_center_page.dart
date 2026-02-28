import 'package:flutter/material.dart';

import 'package:tarumt_carpool/services/driver_verification/driver/driver_verification_service.dart';
import 'package:tarumt_carpool/services/driver_verification/driver/driver_verification_mapper.dart';
import 'package:tarumt_carpool/shared/open_url.dart';

import 'package:tarumt_carpool/widgets/driver_verification/vehicle_and_driver_status_card.dart';
import 'package:tarumt_carpool/widgets/driver_verification/status_button.dart';
import 'package:tarumt_carpool/widgets/driver_verification/dv_info_card.dart';
import 'package:tarumt_carpool/widgets/driver_verification/dv_files_card.dart';
import 'package:tarumt_carpool/widgets/driver_verification/dv_reject_card.dart';
import 'package:tarumt_carpool/widgets/layout/app_scaffold.dart';

import 'driver_verification_form_page.dart';

class DriverVerificationCenterPage extends StatelessWidget {
  DriverVerificationCenterPage({super.key});


  final DriverVerificationService _svc = DriverVerificationService();

  _ActionConfig _actionConfig(String status) {
    switch (status) {
      case 'pending':
        return const _ActionConfig(text: 'Submitted (Pending Review)', enabled: false); //waiting for admin approve
      case 'approved':
        return const _ActionConfig(text: 'Verified', enabled: false); //after admin approved
      case 'rejected':
        return const _ActionConfig(text: 'Reapply for Driver Verification', enabled: true); //apply after rejected
      default:
        return const _ActionConfig(text: 'Apply for Driver Verification', enabled: true); //first time apply
    }
  }

  @override
  Widget build(BuildContext context) {

    return AppScaffold(
      title: 'Driver Verification Center',
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: _svc.streamMyVerification(),  //listens to Firestore in real time.
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());  //show loading spinner
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final view = (snap.data == null)
              ? DriverVerificationViewData.empty()  //the user havent submit
              : DriverVerificationViewData.fromDoc(snap.data!); //convert firestore data into Dart object using fromDoc

          final action = _actionConfig(view.status);
          final reason = (view.rejectReason ?? '').trim();     //means If rejectReason is null → use empty string '', If not null → use rejectReason

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
                  onOpen: (url) => openExternalUrl(context, url),
                ),

                // ✅ FIX: show reject reason
                if (view.status == 'rejected' && reason.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DvRejectCard(reason: reason),
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
                  textAlign: TextAlign.center,
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
