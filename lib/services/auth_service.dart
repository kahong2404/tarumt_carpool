import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../repositories/user_repository.dart';
import '../utils/validators.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _users = UserRepository();

  String? get currentUid => _auth.currentUser?.uid;

  Future<void> register({
    required String role, // 'rider' or 'driver'
    required String staffId,
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final errs = Validators.validateRegisterCore(
      email: email,
      staffId: staffId,
      name: name,
      phone: phone,
      password: password,
    );
    if (errs.isNotEmpty) throw Exception(errs.join('\n'));

    final emailLower = email.trim().toLowerCase();
    final staffIdTrim = staffId.trim();
    final phoneTrim = phone.trim();
    final initialRole = role.trim(); // rider/driver

    final dupErrors = await _users.checkDuplicates(
      staffId: staffIdTrim,
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
      staffId: staffIdTrim,
      name: name.trim(),
      email: emailLower,
      phone: phoneTrim,
      roles: [initialRole],
      activeRole: initialRole,
      driverStatus: initialRole == 'driver' ? 'pending' : 'not_driver',
      walletBalance: 0,
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
