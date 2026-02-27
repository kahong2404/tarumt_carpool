import 'app_strings.dart';

class Validators {
  // ----------------------
  // Single-field checks
  // ----------------------
  static bool isTarumtEmail(String email) {
    final e = email.trim().toLowerCase();
    return e.endsWith('@student.tarc.edu.my') || e.endsWith('@tarc.edu.my');
  }

  static bool isValiduserId(String id) =>
      RegExp(r'^\d{7}$').hasMatch(id.trim());

  static bool isValidName(String name) {
    final n = name.trim();
    return n.isNotEmpty && RegExp(r'^[A-Za-z ]+$').hasMatch(n);
  }

  static String normalizeMalaysiaPhone(String phone) {
    String p = phone.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (p.startsWith('+')) p = p.substring(1);
    if (p.startsWith('01')) p = '6$p'; // 01xxxx -> 601xxxx
    return p;
  }

  static bool isValidMalaysiaPhone(String phone) {
    final p = normalizeMalaysiaPhone(phone);
    return RegExp(r'^60(1)\d{8,9}$').hasMatch(p);
  }

  static bool isStrongPassword(String password) {
    if (password.length < 12) return false;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'\d').hasMatch(password);
    final hasSymbol = RegExp(r'[^\w\s]').hasMatch(password);
    return hasUpper && hasLower && hasNumber && hasSymbol;
  }

  // ----------------------
  // Shared "add once"
  // ----------------------
  static void _add(List<String> list, String msg) {
    if (!list.contains(msg)) list.add(msg);
  }

  // ----------------------
  // Register (service)
  // - No confirm password here
  // ----------------------
  static List<String> validateRegisterCore({
    required String email,
    required String userId,
    required String name,
    required String phone,
    required String password,
  }) {
    final errors = <String>[];

    // Email
    if (email.trim().isEmpty) {
      _add(errors, AppStrings.enterTarumtEmail);
    } else if (!isTarumtEmail(email)) {
      _add(errors, AppStrings.invalidTarumtEmail);
    }

    // Staff ID
    if (userId.trim().isEmpty) {
      _add(errors, AppStrings.enteruserId);
    } else if (!isValiduserId(userId)) {
      _add(errors, AppStrings.invaliduserId);
    }

    // Name
    if (name.trim().isEmpty) {
      _add(errors, AppStrings.enterName);
    } else if (!isValidName(name)) {
      _add(errors, AppStrings.invalidName);
    }

    // Phone
    if (phone.trim().isEmpty) {
      _add(errors, AppStrings.enterPhone);
    } else if (!isValidMalaysiaPhone(phone)) {
      _add(errors, AppStrings.invalidPhone);
    }

    // Password
    if (password.isEmpty) {
      _add(errors, AppStrings.enterPassword);
    } else if (!isStrongPassword(password)) {
      _add(errors, AppStrings.weakPassword);
    }

    return errors;
  }

  // ----------------------
  // Register (UI)
  // - Adds confirm password check on top of core
  // ----------------------
  static List<String> validateRegisterUI({
    required String email,
    required String userId,
    required String name,
    required String phone,
    required String password,
    required String confirmPassword,
  }) {
    final errors = validateRegisterCore(
      email: email,
      userId: userId,
      name: name,
      phone: phone,
      password: password,
    );

    if (confirmPassword.isEmpty) {
      _add(errors, AppStrings.enterConfirmPassword);
    } else if (password.isNotEmpty && password != confirmPassword) {
      _add(errors, AppStrings.passwordNotMatch);
    }

    return errors;
  }

  // ----------------------
  // Login (UI)
  // ----------------------
  static List<String> validateLoginAll({
    required String email,
    required String password,
  }) {
    final errors = <String>[];

    if (email.trim().isEmpty) {
      _add(errors, AppStrings.enterTarumtEmail);
    } else if (!isTarumtEmail(email)) {
      _add(errors, AppStrings.invalidTarumtEmail);
    }

    if (password.isEmpty) {
      _add(errors, AppStrings.enterPassword);
    }

    return errors;
  }

  // ----------------------
  // Forgot password (UI)
  // ----------------------
  static List<String> validateForgotPasswordAll({
    required String email,
  }) {
    final errors = <String>[];

    if (email.trim().isEmpty) {
      _add(errors, AppStrings.enterTarumtEmail);
    } else if (!isTarumtEmail(email)) {
      _add(errors, AppStrings.invalidTarumtEmail);
    }

    return errors;
  }

  // Edit Profile
  static List<String> validateEditPhone({
    required String phone,
  }) {
    final errors = <String>[];

    if (phone.trim().isEmpty) {
      _add(errors, AppStrings.enterPhone);
      return errors;
    }

    if (!isValidMalaysiaPhone(phone)) {
      _add(errors, AppStrings.invalidPhone);
    }

    return errors;
  }


}
