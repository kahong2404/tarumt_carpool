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

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'staffId': staffId,
    'phone': phone,
    'role': role,
    'driverStatus': driverStatus,
    'walletBalance': walletBalance,
  };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    uid: map['uid'] ?? '',
    email: map['email'] ?? '',
    staffId: map['staffId'] ?? '',
    phone: map['phone'] ?? '',
    role: map['role'] ?? 'rider',
    driverStatus: map['driverStatus'] ?? 'not_driver',
    walletBalance: (map['walletBalance'] ?? 0) is int
        ? (map['walletBalance'] ?? 0)
        : (map['walletBalance'] as num).toInt(),
  );
}
