import 'package:firebase_auth/firebase_auth.dart';
import 'app_strings.dart';

class AppErrors {
  static String friendly(Object e) {
    // ✅ Firebase auth errors
    if (e is FirebaseAuthException) {
      switch (e.code) {

      // 🔥 IMPORTANT: new Firebase SDK error
        case 'invalid-credential':
        case 'wrong-password':
          return AppStrings.wrongPassword; // "Incorrect email or password."

        case 'user-not-found':
          return AppStrings.noAccountFound;

        case 'invalid-email':
          return AppStrings.invalidEmailFormat;

        case 'email-already-in-use':
          return AppStrings.emailAlreadyRegistered;

        case 'weak-password':
          return AppStrings.weakPasswordFirebase;

        case 'too-many-requests':
          return AppStrings.tooManyAttempts;

        case 'network-request-failed':
          return AppStrings.networkError;

        case 'user-disabled':
          return AppStrings.accountDisabled;

        default:
        // ❌ NEVER show raw Firebase message to user
          return AppStrings.genericAuthError;
      }
    }

    // ✅ Your custom repo exception strings
    final msg = e.toString();
    if (msg.contains('Student/Staff ID already exists')) {
      return AppStrings.staffIdAlreadyRegistered;
    }
    if (msg.contains('Phone number already exists')) {
      return AppStrings.phoneAlreadyRegistered;
    }
    if (msg.contains('Email already registered')) {
      return AppStrings.emailAlreadyRegistered;
    }

    // fallback (safe)
    return AppStrings.genericError;
  }
}
