class AppUser {
  final String uid;
  final String staffId;
  final String name;
  final String email;
  final String phone;

  final List<String> roles; // ['rider'], ['driver'], ['rider','driver'], ['admin']
  final String activeRole;  // 'rider' | 'driver' | 'admin'

  final String driverStatus; // not_driver | pending | approved | rejected
  final int walletBalance;
  final String? photoUrl;

  AppUser({
    required this.uid,
    required this.staffId,
    required this.name,
    required this.email,
    required this.phone,
    required this.roles,
    required this.activeRole,
    required this.driverStatus,
    required this.walletBalance,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'staffId': staffId,
      'name': name,
      'email': email,
      'phone': phone,
      'roles': roles,
      'activeRole': activeRole,
      'driverStatus': driverStatus,
      'walletBalance': walletBalance,
      'photoUrl': photoUrl,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: (map['uid'] ?? '').toString(),
      staffId: (map['staffId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      roles: List<String>.from(map['roles'] ?? const <String>[]),
      activeRole: (map['activeRole'] ?? 'rider').toString(),
      driverStatus: (map['driverStatus'] ?? 'not_driver').toString(),
      walletBalance: (map['walletBalance'] ?? 0) as int,
      photoUrl: map['photoUrl']?.toString(),
    );
  }
}
