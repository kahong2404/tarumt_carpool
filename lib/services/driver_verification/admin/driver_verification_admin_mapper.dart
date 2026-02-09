import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:tarumt_carpool/models/driver_verification_application.dart';
import 'package:tarumt_carpool/models/driver_verification_profile.dart';

/// Admin-side mapping helpers.
/// Keeps ALL field names consistent with Firestore schema:
///
/// driver_verifications/{userId}
/// - vehicle: { model, plateNumber, color, imageUrl }
/// - documents: { licensePdfUrl, insurancePdfUrl }
/// - verification: { status, rejectionReason, reviewedBy, reviewedAt }
class DriverVerificationAdminMapper {
  // ----------------------------
  // Safe field extraction
  // ----------------------------
  static DriverVerificationApplication toApplication({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    return DriverVerificationApplication(
      userId: userId,
      uid: (data['uid'] ?? '').toString(),
      submittedAt: data['submittedAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      profile: DriverVerificationProfile.fromMap(data),
    );
  }

  /// Show a nice date for admin card (prefer submittedAt, fallback updatedAt)
  static Timestamp? bestCreatedAt(DriverVerificationApplication app) {
    return app.submittedAt ?? app.updatedAt;
  }

  // ----------------------------
  // UI Helpers (status text/color)
  // ----------------------------
  static String statusLabel(String s) {
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

  static Color statusColor(String s) {
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
}
