import 'package:cloud_firestore/cloud_firestore.dart';

class WalletRepository {
  WalletRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // Collections
  CollectionReference<Map<String, dynamic>> get users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get txRoot =>
      _db.collection('walletTransactions');

  // References
  DocumentReference<Map<String, dynamic>> userRef(String uid) =>
      users.doc(uid);

  /// Stream user document (contains walletBalance cents)
  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String uid) =>
      userRef(uid).snapshots();

  /// Get current balance (cents) once
  Future<int> getWalletBalanceCents(String uid) async {
    final doc = await userRef(uid).get();
    final data = doc.data() ?? {};
    return (data['walletBalance'] ?? 0) as int; // ✅ cents int
  }

  /// Latest N transactions (for wallet home screen)
  Stream<QuerySnapshot<Map<String, dynamic>>> latestTxStream(
      String uid, {
        int limit = 5,
      }) {
    return txRoot
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// All transactions (for view all)
  Stream<QuerySnapshot<Map<String, dynamic>>> allTxStream(String uid) {
    return txRoot
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
