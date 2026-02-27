import 'package:firebase_auth/firebase_auth.dart';
import 'package:tarumt_carpool/models/app_user.dart';
import 'package:tarumt_carpool/repositories/user_repository.dart';
import 'package:tarumt_carpool/utils/validators.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _users = UserRepository();

  String? get currentUid => _auth.currentUser?.uid;

  Future<void> register({
    required String role, // 'rider' or 'driver'
    required String userId,
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final errs = Validators.validateRegisterCore(
      email: email,
      userId: userId,
      name: name,
      phone: phone,
      password: password,
    );
    if (errs.isNotEmpty) throw Exception(errs.join('\n'));

    final emailLower = email.trim().toLowerCase();
    final userIdTrim = userId.trim();
    final phoneTrim = phone.trim();
    final initialRole = role.trim(); // rider/driver

    final dupErrors = await _users.checkDuplicates(
      userId: userIdTrim,
      phone: phoneTrim,
      emailLower: emailLower,
    );
    if (dupErrors.isNotEmpty) throw Exception(dupErrors.join('\n'));

    final cred = await _auth.createUserWithEmailAndPassword(
      email: emailLower,
      password: password,
    );

    final uid = cred.user!.uid;

    final appUser = AppUser(
      uid: uid,
      userId: userIdTrim,
      name: name.trim(),
      email: emailLower,
      phone: phoneTrim,
      roles: [initialRole],
      activeRole: initialRole,
      driverStatus: 'not_applied',
      walletBalanceCents: 0,
      photoUrl: null,
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
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
