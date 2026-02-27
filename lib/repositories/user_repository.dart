import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tarumt_carpool/models/app_user.dart' show AppUser;

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance; //let user read/write Firestore
  final FirebaseAuth _auth = FirebaseAuth.instance; //get the currently logged-in users

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

//Before registering, it checks if userId, phone, email already exist in Firestore
  Future<List<String>> checkDuplicates({
    required String userId,
    required String phone,
    required String emailLower,
  }) async {
    final errors = <String>[];
    final userIdTrim = userId.trim();
    final phoneTrim = phone.trim();
    final emailTrim = emailLower.trim();

    final userIdDup = await _users.where('userId', isEqualTo: userIdTrim).limit(1).get();
    if (userIdDup.docs.isNotEmpty) errors.add('Student/Staff ID already registered.');
    if (phoneTrim.isNotEmpty) {
      final phoneDup = await _users.where('phone', isEqualTo: phoneTrim).limit(1).get();
      if (phoneDup.docs.isNotEmpty) errors.add('Phone number already registered.');
    }
    final emailDup = await _users.where('email', isEqualTo: emailTrim).limit(1).get();
    if (emailDup.docs.isNotEmpty) errors.add('Email already registered.');
    return errors;
  }

//Create user (register)
  Future<void> createUser(AppUser user) async {
    final uid = user.uid;
    final ref = _users.doc(uid);
    final snap = await ref.get();
    if (snap.exists) throw Exception('User already exists.');
    await ref.set({
      ...user.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

//read the current yser
  Future<AppUser?> getCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null; //if no login
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;   //if the user document havent create
    return AppUser.fromMap(doc.data()!);
  }


  //Returns real-time updates
  Stream<Map<String, dynamic>?> streamUserDoc(String uid) {
    return _users.doc(uid).snapshots().map((doc) => doc.data());
  }

  // You only need one small field
  // You don’t need full AppUser model
  // You want quick raw access
  Future<Map<String, dynamic>?> getUserDocMap(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  // get userId of current logged-in user
  Future<String?> getuserIdOfCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    final userId = (data?['userId'] ?? '').toString().trim();
    if (userId.isEmpty) return null;
    return userId;
  }

  // =========================
  // PROFILE: PHONE UPDATE
  // =========================
  Future<void> updatePhone({
    required String uid,
    required String newPhone,
  }) async {
    final phoneTrim = newPhone.trim();
    if (phoneTrim.isEmpty) throw Exception('Please enter your phone number.');
    final q = await _users.where('phone', isEqualTo: phoneTrim).limit(1).get();
    if (q.docs.isNotEmpty && q.docs.first.id != uid) {
      throw Exception('Phone number already registered.');
    }
    await _users.doc(uid).update({
      'phone': phoneTrim,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePhotoUrl({
    required String uid,
    required String photoUrl,
  }) async {
    await _users.doc(uid).update({
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

//Change which role the user is currently using
  Future<void> setActiveRole({
    required String uid,
    required String activeRole,
  }) async {
    await _users.doc(uid).update({
      'activeRole': activeRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addRoleIfMissing({
    required String uid,
    required String role,
  }) async {
    await _users.doc(uid).update({
      'roles': FieldValue.arrayUnion([role]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

}
