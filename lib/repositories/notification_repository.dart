import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _col() {
    final uid = _auth.currentUser!.uid;
    return _db.collection('users').doc(uid).collection('notifications');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyNotifications() {
    return _col().orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> markRead(String id) async {
    await _col().doc(id).update({'isRead': true});
  }
}
