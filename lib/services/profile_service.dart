import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../repositories/user_repository.dart';
import '../utils/validators.dart';

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

  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Delete account:
  /// 1) delete Firestore user doc
  /// 2) delete profile image in Storage (ignore if missing)
  /// 3) delete FirebaseAuth user (may require recent login)
  Future<void> deleteAccount() async {
    final uid = _uid;
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in.');

    // delete Firestore profile
    await _db.collection('users').doc(uid).delete();

    // delete storage image
    try {
      await _storage.ref('profile_images/$uid.jpg').delete();
    } catch (_) {}

    // delete auth user
    await user.delete();
  }
}
