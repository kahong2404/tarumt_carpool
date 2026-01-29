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
          staffId: d.id,
          data: d.data(),
        );
      }).toList();
    });
  }

  Stream<DriverVerificationApplication?> streamApplication(String staffId) {
    return _repo.streamByStaffIdRaw(staffId).map((doc) {
      // ✅ IMPORTANT: even "not found" should return NULL (so UI can stop loading)
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;

      return DriverVerificationApplication.fromDoc(
        staffId: doc.id,
        data: data,
      );
    });
  }

  Future<void> approve({required String staffId, required String reviewerUid}) {
    return _repo.reviewApplicationRaw(
      staffId: staffId,
      decision: 'approved',
      reviewerUid: reviewerUid,
    );
  }

  Future<void> reject({
    required String staffId,
    required String reviewerUid,
    required String reason,
  }) {
    return _repo.reviewApplicationRaw(
      staffId: staffId,
      decision: 'rejected',
      reviewerUid: reviewerUid,
      rejectReason: reason,
    );
  }
}
