import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../repositories/user_repository.dart';
import '../utils/validators.dart';
import '../utils/app_strings.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _users = UserRepository();

  String? get currentUid => _auth.currentUser?.uid;

  Future<void> register({
    required String role, // rider | driver
    required String staffId,
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    // (UI already validates, but keep safety here)
    if (!Validators.isTarumtEmail(email)) {
      throw Exception(AppStrings.invalidTarumtEmail);
    }
    if (!Validators.isValidStaffId(staffId)) {
      throw Exception(AppStrings.invalidStaffId); // ✅ 7 digits
    }
    if (!Validators.isValidName(name)) {
      throw Exception(AppStrings.invalidName);
    }
    if (!Validators.isValidMalaysiaPhone(phone)) {
      throw Exception(AppStrings.invalidPhone);
    }
    if (!Validators.isStrongPassword(password)) {
      throw Exception(AppStrings.weakPassword);
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    final uid = cred.user!.uid;

    final appUser = AppUser(
      uid: uid,
      staffId: staffId.trim(),
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      role: role,
      driverStatus: role == 'driver' ? 'pending' : 'not_driver',
      walletBalance: 0,
    );

    try {
      await _users.createUser(appUser);
    } catch (e) {
      await cred.user?.delete();
      rethrow;
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim().toLowerCase(),
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
