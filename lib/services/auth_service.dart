import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../repositories/user_repository.dart';
import '../utils/validators.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _users = UserRepository();

  String? get currentUid => _auth.currentUser?.uid;

  Future<void> register({
    required String role,
    required String staffId,
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    // 1) core validation
    final errs = Validators.validateRegisterCore(
      email: email,
      staffId: staffId,
      name: name,
      phone: phone,
      password: password,
    );
    if (errs.isNotEmpty) throw Exception(errs.join('\n')); // optional: show all core errors too

    // 2) normalize inputs ONCE
    final emailLower = email.trim().toLowerCase();
    final staffIdTrim = staffId.trim();
    final phoneTrim = phone.trim();

    // ✅ 3) PRECHECK duplicates in Firestore BEFORE FirebaseAuth
    final dupErrors = await _users.checkDuplicates(
      staffId: staffIdTrim,
      phone: phone,
      emailLower: emailLower,
    );

    if (dupErrors.isNotEmpty) {
      throw Exception(dupErrors.join('\n')); // ✅ multiple messages
    }

    // 4) Only now create Firebase Auth user
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
      phone: phone,
      role: role,
      driverStatus: role == 'driver' ? 'pending' : 'not_driver',
      walletBalance: 0,
    );

    try {
      await _users.createUser(appUser); // should pass now
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
