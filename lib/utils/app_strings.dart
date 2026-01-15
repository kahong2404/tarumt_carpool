class AppStrings {
  // ======================
  // Email
  // ======================
  static const enterTarumtEmail = 'Please enter your TARUMT email.';
  static const invalidTarumtEmail = 'Please use a valid TARUMT email.';
  static const invalidEmailFormat = 'Please enter a valid email address.';

  // ======================
  // Staff / Student ID
  // ======================
  static const enterStaffId = 'Please enter your Student/Staff ID.';
  static const invalidStaffId = 'Student/Staff ID must be exactly 7 digits.';
  static const staffIdAlreadyRegistered =
      'Student/Staff ID already registered.';

  // ======================
  // Name
  // ======================
  static const enterName = 'Please enter your full name.';
  static const invalidName = 'Name can contain letters and spaces only.';

  // ======================
  // Phone
  // ======================
  static const enterPhone = 'Please enter your phone number.';
  static const invalidPhone =
      'Phone number must be a valid Malaysia mobile number (e.g., 0123456789).';
  static const phoneAlreadyRegistered =
      'Phone number already registered.';

  // ======================
  // Password
  // ======================
  static const enterPassword = 'Please enter your password.';
  static const enterConfirmPassword = 'Please confirm your password.';
  static const weakPassword =
      'Password must be 12+ characters and include uppercase, lowercase, number, and symbol.';
  static const passwordNotMatch =
      'Password and Confirm Password do not match.';

  // ======================
  // Firebase Auth (USER-FRIENDLY)
  // ======================
  static const emailAlreadyRegistered =
      'This email is already registered.';
  static const noAccountFound =
      'No account found for this email.';
  static const wrongPassword =
      'Incorrect email or password.'; // ✅ IMPORTANT
  static const weakPasswordFirebase =
      'Password is too weak.';
  static const networkError =
      'Network error. Please check your internet connection.';
  static const tooManyAttempts =
      'Too many attempts. Please try again later.';
  static const accountDisabled =
      'This account has been disabled.';

  // ======================
  // Generic / Fallback
  // ======================
  static const genericAuthError =
      'Login failed. Please try again.';
  static const genericError =
      'Something went wrong. Please try again.';
}
