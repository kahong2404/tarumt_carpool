import 'package:cloud_firestore/cloud_firestore.dart';
import 'driver_verification_profile.dart';

class DriverVerificationApplication {
  final String staffId; // doc id
  final String uid;     // stored field
  final Timestamp? createdAt;
  final DriverVerificationProfile profile;

  DriverVerificationApplication({
    required this.staffId,
    required this.uid,
    required this.createdAt,
    required this.profile,
  });

  factory DriverVerificationApplication.fromDoc({
    required String staffId,
    required Map<String, dynamic> data,
  }) {
    return DriverVerificationApplication(
      staffId: staffId,
      uid: (data['uid'] ?? '').toString(),
      createdAt: data['createdAt'] as Timestamp?,
      profile: DriverVerificationProfile.fromMap(data),
    );
  }
}
