import 'package:cloud_firestore/cloud_firestore.dart';
import 'driver_verification_profile.dart';

class DriverVerificationApplication {
  final String staffId; // doc id
  final String uid;

  final Timestamp? submittedAt;
  final Timestamp? updatedAt;

  final DriverVerificationProfile profile;

  DriverVerificationApplication({
    required this.staffId,
    required this.uid,
    required this.submittedAt,
    required this.updatedAt,
    required this.profile,
  });

  factory DriverVerificationApplication.fromDoc({
    required String staffId,
    required Map<String, dynamic> data,
  }) {
    return DriverVerificationApplication(
      staffId: staffId,
      uid: (data['uid'] ?? '').toString(),
      submittedAt: data['submittedAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      profile: DriverVerificationProfile.fromMap(data),
    );
  }
}
