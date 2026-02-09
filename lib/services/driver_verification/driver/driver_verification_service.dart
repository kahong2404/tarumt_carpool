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

  Future<String> getMyuserIdOrThrow() async {
    final userId = await _userRepo.getuserIdOfCurrentUser();
    if (userId == null || userId.trim().isEmpty) {
      throw Exception('Missing userId in user profile.');
    }
    return userId.trim();
  }

  Stream<Map<String, dynamic>?> streamMyVerification() async* {
    final userId = await getMyuserIdOrThrow();
    yield* _repo.streamByuserId(userId);
  }

  Future<void> submitPending({required DriverVerificationProfile profile}) async {
    final uid = myUid;
    final userId = await getMyuserIdOrThrow();
    await _repo.submitPending(uid: uid, userId: userId, profile: profile);
  }
}
