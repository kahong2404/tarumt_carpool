import 'package:flutter/material.dart';

class VehicleAndDriverStatusCard extends StatelessWidget {
  final String vehicleModel;
  final String status;

  const VehicleAndDriverStatusCard({
    super.key,
    required this.vehicleModel,
    required this.status,
  });

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
    final isEmptyVehicle =
        vehicleModel.trim().isEmpty ||
            vehicleModel.toLowerCase().contains('no vehicle');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Card Title
          const Text(
            'Vehicle and Driver Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),

          // 🔹 Label
          const Text(
            'Vehicle',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),

          // 🔹 Value (grey)
          Text(
            isEmptyVehicle ? 'Not submitted' : vehicleModel,
            style: const TextStyle(
              fontSize: 14,                // 👈 ensure same size
              fontWeight: FontWeight.w600, // 👈 same weight
              color: Colors.black54,       // 👈 same grey
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Driver Verification Status',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),

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
                fontWeight: FontWeight.w700,
                color: _statusTextColor(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}