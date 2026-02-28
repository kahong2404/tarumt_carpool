import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tarumt_carpool/widgets/layout/app_scaffold.dart'; //import this
import 'package:tarumt_carpool/models/driver_verification_application.dart';
import 'package:tarumt_carpool/services/driver_verification/admin/driver_verification_review_service.dart';

import 'package:tarumt_carpool/widgets/driver_verification/vehicle_and_driver_status_card.dart';
import 'package:tarumt_carpool/widgets/driver_verification/dv_info_card.dart';
import 'package:tarumt_carpool/widgets/driver_verification/dv_files_card.dart';
import 'package:tarumt_carpool/widgets/driver_verification/dv_reject_card.dart';

class DriverVerificationDetailPage extends StatefulWidget {
  final String userId;
  const DriverVerificationDetailPage({super.key, required this.userId});

  @override
  State<DriverVerificationDetailPage> createState() =>
      _DriverVerificationDetailPageState();
}

class _DriverVerificationDetailPageState extends State<DriverVerificationDetailPage> {
  static const brandBlue = Color(0xFF1E73FF);

  final _svc = DriverVerificationReviewService();
  bool _loading = false;

  Future<void> _openUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file URL found.')),
      );
      return;
    }

    try {
      final uri = Uri.parse(u);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open file.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open file.')),
      );
    }
  }

  Future<String?> _askRejectReason() async {
    final ctrl = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false, // ✅ force explicit action
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Reject Application'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter reject reason',
                      border: const OutlineInputBorder(),
                      errorText: errorText, // ✅ inline validation message
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final text = ctrl.text.trim();

                    if (text.isEmpty) {
                      // ✅ VALIDATION HERE
                      setState(() {
                        errorText = 'Reject reason cannot be empty.';
                      });
                      return;
                    }

                    Navigator.pop(dialogCtx, text);
                  },
                  child: const Text('Reject'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _approve() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;
      if (adminUid == null) throw Exception('Not signed in.');

      await _svc.approve(userId: widget.userId, reviewerUid: adminUid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application approved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approve failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final reason = await _askRejectReason();
    if (reason == null) return;

    if (_loading) return;
    setState(() => _loading = true);

    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;
      if (adminUid == null) throw Exception('Not signed in.');

      await _svc.reject(
        userId: widget.userId,
        reviewerUid: adminUid,
        reason: reason,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application rejected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _bottomActions({required bool canReview}) {
    if (!canReview) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _loading ? null : _reject,
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
                onPressed: _loading ? null : _approve,
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
    return AppScaffold(   //change to this
      title: 'Staff ID: ${widget.userId}',
      child: StreamBuilder<DriverVerificationApplication?>(
        stream: _svc.streamApplication(widget.userId),
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
          final canReview = p.status == 'pending';

          final vehicleModel =
          p.vehicleModel.trim().isEmpty ? '-' : p.vehicleModel.trim();

          final lastReason = (p.lastRejectReason ?? '').trim();
          final currentRejectReason = (p.rejectReason ?? '').trim();

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                children: [
                  VehicleAndDriverStatusCard(
                    vehicleModel: vehicleModel,
                    status: p.status,
                  ),
                  const SizedBox(height: 12),

                  DvInfoCard(
                    title: 'Submitted Details',
                    rows: [
                      DvInfoRow(label: 'Staff ID', value: app.userId),
                      DvInfoRow(label: 'Vehicle', value: vehicleModel),
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
                      currentRejectReason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DvRejectCard(reason: currentRejectReason),
                  ],

                  if (p.status == 'pending' &&
                      lastReason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DvRejectCard(
                        reason: 'Previous reject reason: $lastReason'),
                  ],
                ],
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _bottomActions(canReview: canReview),
              ),
            ],
          );
        },
      ),
    );
  }
}
