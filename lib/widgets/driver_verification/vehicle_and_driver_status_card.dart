import 'package:flutter/material.dart';

class VehicleAndDriverStatusCard extends StatelessWidget {
  final String vehicleModel;
  final String status; // not_applied | pending | approved | rejected

  const VehicleAndDriverStatusCard({
    super.key,
    required this.vehicleModel,
    required this.status,
  });

  // -------------------------
  // Status helpers
  // -------------------------
  Color _statusBackgroundColor() {
    switch (status) {
      case 'approved':
        return const Color(0xFFE8F5E9);
      case 'rejected':
        return const Color(0xFFFFEBEE);
      case 'pending':
        return const Color(0xFFFFF8E1);
      default:
        return const Color(0xFFF2F2F2);
    }
  }

  Color _statusTextColor() {
    switch (status) {
      case 'approved':
        return const Color(0xFF2E7D32);
      case 'rejected':
        return const Color(0xFFC62828);
      case 'pending':
        return const Color(0xFFF57F17);
      default:
        return const Color(0xFF616161);
    }
  }

  String _statusLabel() {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      default:
        return 'Not Applied';
    }
  }

  @override
  Widget build(BuildContext context) {
    // darker label + bigger title as you requested
    const titleStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w900);
    const labelStyle = TextStyle(
      color: Color(0xFF111827), // deep
      fontWeight: FontWeight.w900,
    );
    const valueStyle = TextStyle(
      color: Color(0xFF111827),
      fontWeight: FontWeight.w800,
    );
    const hintStyle = TextStyle(
      color: Color(0xFF6B7280),
      fontWeight: FontWeight.w800,
    );

    final isEmptyVehicle = vehicleModel.trim().isEmpty ||
        vehicleModel.toLowerCase().contains('no vehicle');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vehicle & Driver Status', style: titleStyle),
          const SizedBox(height: 14),

          const Text('Vehicle', style: labelStyle),
          const SizedBox(height: 6),
          Text(
            isEmptyVehicle ? 'No vehicle submitted' : vehicleModel,
            style: isEmptyVehicle ? hintStyle : valueStyle,
          ),

          const SizedBox(height: 16),

          const Text('Driver Verification Status', style: labelStyle),
          const SizedBox(height: 10),

          // status pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _statusBackgroundColor(),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _statusTextColor().withOpacity(0.25),
              ),
            ),
            child: Text(
              _statusLabel(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _statusTextColor(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
