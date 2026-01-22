import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminApplicationCard extends StatelessWidget {
  final String staffId;
  final String vehicleModel;
  final String status;
  final Timestamp? createdAt;
  final VoidCallback onTap;

  const AdminApplicationCard({
    super.key,
    required this.staffId,
    required this.vehicleModel,
    required this.status,
    required this.createdAt,
    required this.onTap,
  });

  static const brandBlue = Color(0xFF1E73FF);

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return const Color(0xFFFFB300); // amber
      case 'approved':
        return const Color(0xFF2E7D32); // green
      case 'rejected':
        return const Color(0xFFC62828); // red
      default:
        return Colors.black45;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Not Applied';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = createdAt == null
        ? '-'
        : '${createdAt!.toDate().toLocal()}'.split('.').first;

    final c = _statusColor(status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 46,
              decoration: BoxDecoration(
                color: c.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicleModel.isEmpty ? 'Unknown Vehicle' : vehicleModel,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Staff ID: $staffId',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Created: $dateText',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.withOpacity(0.25)),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
