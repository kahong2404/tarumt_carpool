class AppUser {
  final String uid;
  final String userId;
  final String name;
  final String email;
  final String phone;
  final List<String> roles; // ['rider'], ['driver'], ['rider','driver'], ['admin']
  final String activeRole;  // 'rider' | 'driver' | 'admin'
  final String driverStatus; // not_driver | pending | approved | rejected | not_applied
  final int walletBalanceCents; //Meaning: CENTS (e.g. 7000 = RM70.00)
  final String? photoUrl;

  //Constructor
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

  //converts object into Firestore format.
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
      'walletBalance': walletBalanceCents,
      'photoUrl': photoUrl,
    };
  }

  //Firestore document into AppUser object
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
      walletBalanceCents: (map['walletBalance'] ?? 0) as int,
      photoUrl: map['photoUrl']?.toString(),
    );
  }


}
