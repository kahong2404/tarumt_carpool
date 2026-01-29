import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tarumt_carpool/models/driver_verification_application.dart';
import 'package:tarumt_carpool/services/driver_verification/admin/driver_verification_review_service.dart';

import 'package:tarumt_carpool/widgets/driver_verification/vehicle_and_driver_status_card.dart';
import 'package:tarumt_carpool/widgets/driver_verification/dv_info_card.dart';
import 'package:tarumt_carpool/widgets/driver_verification/dv_files_card.dart';
import 'package:tarumt_carpool/widgets/driver_verification/dv_reject_card.dart';

class DriverVerificationDetailPage extends StatefulWidget {
  final String staffId;
  const DriverVerificationDetailPage({super.key, required this.staffId});

  @override
  State<DriverVerificationDetailPage> createState() =>
      _DriverVerificationDetailPageState();
}

class _DriverVerificationDetailPageState
    extends State<DriverVerificationDetailPage> {
  static const brandBlue = Color(0xFF1E73FF);

  final _svc = DriverVerificationReviewService();
  bool _loading = false;

  // 🔹 Simple default SnackBar (same style as "Phone number updated")
  void _showSimpleSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      if (url.trim().isEmpty) return;
      final uri = Uri.parse(url);

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _showSimpleSnack('Failed to open file.');
    } catch (_) {
      _showSimpleSnack('Failed to open file.');
    }
  }

  Future<void> _approve() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;
      if (adminUid == null) throw Exception('Not signed in.');

      await _svc.approve(
        staffId: widget.staffId,
        reviewerUid: adminUid,
      );

      _showSimpleSnack('Application approved successfully!');
    } catch (e) {
      _showSimpleSnack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Application'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter reject reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    final r = (reason ?? '').trim();
    if (r.isEmpty) return;

    if (_loading) return;
    setState(() => _loading = true);

    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;
      if (adminUid == null) throw Exception('Not signed in.');

      await _svc.reject(
        staffId: widget.staffId,
        reviewerUid: adminUid,
        reason: r,
      );

      _showSimpleSnack('Application rejected successfully!');
    } catch (e) {
      _showSimpleSnack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _bottomActions({required bool canReview}) {
    if (!canReview) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: (_loading || !canReview) ? null : _reject,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEBEE),
                  foregroundColor: const Color(0xFFC62828),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Reject'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: (_loading || !canReview) ? null : _approve,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8F5E9),
                  foregroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Approve'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        title: Text('Staff ID: ${widget.staffId}'),
      ),
      body: StreamBuilder<DriverVerificationApplication?>(
        stream: _svc.streamApplication(widget.staffId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  snap.error.toString(),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final app = snap.data;
          if (app == null) {
            return const Center(child: Text('Application not found.'));
          }

          final p = app.profile;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              VehicleAndDriverStatusCard(
                vehicleModel: p.model.isEmpty ? '-' : p.model,
                status: p.status,
              ),
              const SizedBox(height: 12),

              DvInfoCard(
                title: 'Submitted Details',
                rows: [
                  DvInfoRow(label: 'Staff ID', value: app.staffId),
                  DvInfoRow(label: 'Vehicle', value: p.model),
                  DvInfoRow(label: 'Plate', value: p.plateNumber),
                  DvInfoRow(label: 'Color', value: p.color),
                ],
              ),
              const SizedBox(height: 12),

              DvFilesCard(
                vehicleUrl: p.vehicleImageUrl,
                licenseUrl: p.licensePdfUrl,
                insuranceUrl: p.insurancePdfUrl,
                onOpen: _openUrl,
              ),

              if (p.status == 'rejected' &&
                  (p.rejectReason ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                DvRejectCard(reason: p.rejectReason!.trim()),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<DriverVerificationApplication?>(
        stream: _svc.streamApplication(widget.staffId),
        builder: (context, snap) {
          final canReview = snap.data?.profile.status == 'pending';
          return _bottomActions(canReview: canReview);
        },
      ),
    );
  }
}
