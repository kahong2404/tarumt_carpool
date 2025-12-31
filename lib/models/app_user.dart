class AppUser {
  final String uid;
  final String email;
  final String staffId;
  final String phone;
  final String role;
  final String driverStatus;
  final int walletBalance;

  AppUser({
    required this.uid,
    required this.email,
    required this.staffId,
    required this.phone,
    required this.role,
    required this.driverStatus,
    required this.walletBalance,
  });

  // Object → Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'staffId': staffId,
      'phone': phone,
      'role': role,
      'driverStatus': driverStatus,
      'walletBalance': walletBalance,
    };
  }

  // Firestore → Object (for later use)
  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      staffId: data['staffId'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'rider',
      driverStatus: data['driverStatus'] ?? 'not_driver',
      walletBalance: data['walletBalance'] ?? 0,
    );
  }
}
