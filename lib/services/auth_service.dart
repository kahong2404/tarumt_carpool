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
    // Double check the field again
    if (!Validators.isTarumtEmail(email)) {
      throw Exception(AppStrings.invalidTarumtEmail);
    }
    if (!Validators.isValidStaffId(staffId)) {
      throw Exception(AppStrings.invalidStaffId);
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
    ); // Creates account in Firebase Auth and return User credential

    final uid = cred.user!.uid; // get the uid by the User credential

    final appUser = AppUser( //creates one AppUser object that represents the user’s profile data
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
      await _users.createUser(appUser); //to save user profile in the firestore
    } catch (e) {
      await cred.user?.delete();  // deletes the Firebase Auth account that was just created
      rethrow; //same error back to AuthService.register() because it only can check the email and password need to create account to check the firestore
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
