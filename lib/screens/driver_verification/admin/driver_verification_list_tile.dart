import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tarumt_carpool/models/driver_verification_application.dart';

class DriverVerificationListTile extends StatelessWidget {
  final DriverVerificationApplication app;
  final VoidCallback onTap;

  const DriverVerificationListTile({
    super.key,
    required this.app,
    required this.onTap,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return const Color(0xFF2E7D32);
      case 'rejected':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFFF57F17);
    }
  }

  Color _statusBg(String s) => _statusColor(s).withOpacity(0.12);

  String _statusLabel(String s) {
    switch (s) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    final day = d.day.toString().padLeft(2, '0');
    final month = _monthName(d.month);
    final year = d.year.toString();

    int h = d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;

    return '$day $month $year • $h:$m $ampm';
  }

  String _monthName(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[(m - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    final p = app.profile;
    final status = p.status;
    final c = _statusColor(status);

    // If you don't have name in doc, show vehicle model (like placeholder)
    final title = (p.model.isNotEmpty) ? p.model : 'Driver Application';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 6),
            color: Color(0x14000000),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusBg(status),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.withOpacity(0.25)),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(fontWeight: FontWeight.w900, color: c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            app.staffId,
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),

          Text(
            _formatDateTime(app.createdAt),
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 14),

          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E73FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Click for Review',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
