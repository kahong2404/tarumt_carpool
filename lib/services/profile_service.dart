import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:tarumt_carpool/repositories/user_repository.dart';
import 'package:tarumt_carpool/utils/validators.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final UserRepository _repo = UserRepository();

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in.');
    return uid;
  }

  Future<void> uploadProfileImage(File file) async {
    final uid = _uid;
    final ref = _storage.ref('profile_images/$uid.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await _repo.updatePhotoUrl(uid: uid, photoUrl: url);
  }

  Future<void> updatePhoneRaw(String phoneInput) async {
    final phone = phoneInput.trim();
    if (phone.isEmpty) throw Exception('Please enter your phone number.');
    if (!Validators.isValidMalaysiaPhone(phone)) {
      throw Exception('Invalid Malaysia phone number.');
    }
    await _repo.updatePhone(uid: _uid, newPhone: phone);
  }

  // ✅ Switch mode
  Future<void> switchToDriver() async {
    await _repo.setActiveRole(uid: _uid, activeRole: 'driver');
  }

  Future<void> switchToRider() async {
    await _repo.setActiveRole(uid: _uid, activeRole: 'rider');
  }

  // ✅ Become (add role + switch)
  Future<void> becomeDriver() async {
    final uid = _uid;
    await _repo.addRoleIfMissing(uid: uid, role: 'driver');
    await _repo.setActiveRole(uid: uid, activeRole: 'driver');
  }

  Future<void> becomeRider() async {
    final uid = _uid;
    await _repo.addRoleIfMissing(uid: uid, role: 'rider');
    await _repo.setActiveRole(uid: uid, activeRole: 'rider');
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    final uid = _uid;
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in.');

    await _db.collection('users').doc(uid).delete();

    try {
      await _storage.ref('profile_images/$uid.jpg').delete();
    } catch (_) {}

    await user.delete();
  }
}
