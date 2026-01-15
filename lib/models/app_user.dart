class AppUser {
  final String uid; // FirebaseAuth UID
  final String staffId; // ✅ we will use this as Firestore docId
  final String name;
  final String email;
  final String phone; // original phone input
  final String role; // rider | driver | admin
  final String driverStatus; // not_driver | pending | approved | rejected
  final int walletBalance;

  AppUser({
    required this.uid,
    required this.staffId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.driverStatus,
    required this.walletBalance,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'staffId': staffId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'driverStatus': driverStatus,
      'walletBalance': walletBalance,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      staffId: map['staffId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'rider',
      driverStatus: map['driverStatus'] ?? 'not_driver',
      walletBalance: (map['walletBalance'] ?? 0) as int,
    );
  }
}
