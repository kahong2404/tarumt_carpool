import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmService {
  final _messaging = FirebaseMessaging.instance;
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<void> initAndSaveToken() async {
    // Ask permission (needed for iOS, ok for Android)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final token = await _messaging.getToken();
    if (token != null) {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      });
    }

    // keep token fresh
    _messaging.onTokenRefresh.listen((newToken) async {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await _db.collection('users').doc(uid).update({
        'fcmToken': newToken,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
