import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../repositories/user_repository.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _users = UserRepository();

  bool _isTarumtEmail(String email) {
    final e = email.trim().toLowerCase();
    return e.endsWith('@student.tarc.edu.my') || e.endsWith('@tarc.edu.my');
  }

  Future<void> register({
    required String role,
    required String staffId,
    required String phone,
    required String email,
    required String password,
  }) async {
    if (!_isTarumtEmail(email)) {
      throw Exception('Please use a valid TARUMT email.');
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    final uid = cred.user!.uid;

    final appUser = AppUser(
      uid: uid,
      email: email.trim().toLowerCase(),
      staffId: staffId.trim(),
      phone: phone.trim(),
      role: role,
      driverStatus: role == 'driver' ? 'pending' : 'not_driver',
      walletBalance: 0,
    );

    // 🔥 delegate Firestore to repository
    await _users.createUser(appUser);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    if (!_isTarumtEmail(email)) {
      throw Exception('Please use a valid TARUMT email.');
    }

    await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  String? get currentUid => _auth.currentUser?.uid;
}
