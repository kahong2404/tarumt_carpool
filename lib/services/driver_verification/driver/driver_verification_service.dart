import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;

import 'package:tarumt_carpool/repositories/driver_verification_repository.dart';
import 'package:tarumt_carpool/repositories/user_repository.dart';

class DriverVerificationService {
  final _auth = FirebaseAuth.instance;
  final _userRepo = UserRepository();
  final _repo = DriverVerificationRepository();



  Future<String> getMyuserIdOrThrow() async {
    final userId = await _userRepo.getuserIdOfCurrentUser();  //getcurrent user Id
    if (userId == null || userId.trim().isEmpty) {
      throw Exception('Missing userId in user profile.');
    }
    return userId.trim();
  }

  Stream<Map<String, dynamic>?> streamMyVerification() async* {
    final userId = await getMyuserIdOrThrow();
    yield* _repo.streamByuserId(userId);
  }


}
