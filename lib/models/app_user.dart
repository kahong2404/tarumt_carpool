class AppUser {
  final String uid; // FirebaseAuth UID
  final String staffId;
  final String name;
  final String email;
  final String phone; //phone
  final String role; // rider | driver | admin
  final String driverStatus; // not_driver | pending | approved | rejected
  final int walletBalance;

  //Constructor
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

  //converts a Dart object into a Map (to store in Firestore)
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

  //converts Firestore data back into a Dart object
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
