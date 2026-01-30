import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/driver_verification_profile.dart';
import '../../../repositories/driver_verification_repository.dart';
import '../../../repositories/user_repository.dart';

class DriverVerificationService {
  final _auth = FirebaseAuth.instance;
  final _userRepo = UserRepository();
  final _repo = DriverVerificationRepository();

  String get myUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in.');
    return uid;
  }

  Future<String> getMyStaffIdOrThrow() async {
    final staffId = await _userRepo.getStaffIdOfCurrentUser();
    if (staffId == null || staffId.trim().isEmpty) {
      throw Exception('Missing staffId in user profile.');
    }
    return staffId.trim();
  }

  Stream<Map<String, dynamic>?> streamMyVerification() async* {
    final staffId = await getMyStaffIdOrThrow();
    yield* _repo.streamByStaffId(staffId);
  }

  Future<void> submitPending({required DriverVerificationProfile profile}) async {
    final uid = myUid;
    final staffId = await getMyStaffIdOrThrow();
    await _repo.submitPending(uid: uid, staffId: staffId, profile: profile);
  }
}
