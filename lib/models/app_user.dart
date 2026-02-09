class AppUser {
  final String uid;
  final String userId;
  final String name;
  final String email;
  final String phone;

  final List<String> roles; // ['rider'], ['driver'], ['rider','driver'], ['admin']
  final String activeRole;  // 'rider' | 'driver' | 'admin'

  final String driverStatus; // not_driver | pending | approved | rejected | not_applied

  /// ✅ Firestore key: "walletBalance"
  /// ✅ Meaning: CENTS (e.g. 7000 = RM70.00)
  final int walletBalanceCents;

  final String? photoUrl;

  AppUser({
    required this.uid,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.roles,
    required this.activeRole,
    required this.driverStatus,
    required this.walletBalanceCents,
    this.photoUrl,
  });

  double get walletBalanceRm => walletBalanceCents / 100.0;
  String get formatWalletRm => walletBalanceRm.toStringAsFixed(2);

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'roles': roles,
      'activeRole': activeRole,
      'driverStatus': driverStatus,

      // ✅ Keep DB key as walletBalance (cents int)
      'walletBalance': walletBalanceCents,

      'photoUrl': photoUrl,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: (map['uid'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      roles: List<String>.from(map['roles'] ?? const <String>[]),
      activeRole: (map['activeRole'] ?? 'rider').toString(),
      driverStatus: (map['driverStatus'] ?? 'not_applied').toString(),
      walletBalanceCents: (map['walletBalance'] ?? 0) as int, // ✅ must be int
      photoUrl: map['photoUrl']?.toString(),
    );
  }

  AppUser copyWith({
    String? uid,
    String? userId,
    String? name,
    String? email,
    String? phone,
    List<String>? roles,
    String? activeRole,
    String? driverStatus,
    int? walletBalanceCents,
    String? photoUrl,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      roles: roles ?? this.roles,
      activeRole: activeRole ?? this.activeRole,
      driverStatus: driverStatus ?? this.driverStatus,
      walletBalanceCents: walletBalanceCents ?? this.walletBalanceCents,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
