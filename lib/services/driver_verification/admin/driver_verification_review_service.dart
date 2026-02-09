import 'package:tarumt_carpool/models/driver_verification_application.dart';
import 'package:tarumt_carpool/repositories/driver_verification_review_repository.dart';

class DriverVerificationReviewService {
  final DriverVerificationReviewRepository _repo;

  DriverVerificationReviewService({DriverVerificationReviewRepository? repo})
      : _repo = repo ?? DriverVerificationReviewRepository();

  Stream<List<DriverVerificationApplication>> streamApplications({
    required String status,
    required bool descending,
  }) {
    return _repo.streamListRaw(status: status, descending: descending).map((snap) {
      return snap.docs.map((d) {
        return DriverVerificationApplication.fromDoc(
          userId: d.id,
          data: d.data(),
        );
      }).toList();
    });
  }

  Stream<DriverVerificationApplication?> streamApplication(String userId) {
    return _repo.streamByuserIdRaw(userId).map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;

      return DriverVerificationApplication.fromDoc(
        userId: doc.id,
        data: data,
      );
    });
  }

  Future<void> approve({
    required String userId,
    required String reviewerUid,
  }) {
    return _repo.reviewApplicationRaw(
      userId: userId,
      decision: 'approved',
      reviewerUid: reviewerUid,
    );
  }

  Future<void> reject({
    required String userId,
    required String reviewerUid,
    required String reason,
  }) {
    return _repo.reviewApplicationRaw(
      userId: userId,
      decision: 'rejected',
      reviewerUid: reviewerUid,
      rejectReason: reason,
    );
  }
}
