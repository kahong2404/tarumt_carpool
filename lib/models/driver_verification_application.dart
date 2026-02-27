import 'package:cloud_firestore/cloud_firestore.dart';
import 'driver_verification_profile.dart';

class DriverVerificationApplication {
  final String userId; // doc id
  final String uid;

  final Timestamp? submittedAt;
  final Timestamp? updatedAt;

  final DriverVerificationProfile profile;

  DriverVerificationApplication({
    required this.userId,
    required this.uid,
    required this.submittedAt,
    required this.updatedAt,
    required this.profile,
  });
//Firestore → Dart model (read)
  // Why dont have tpMap becuase Those update specific parts of the document. You NEVER update the entire application at once.
  factory DriverVerificationApplication.fromDoc({
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
}
