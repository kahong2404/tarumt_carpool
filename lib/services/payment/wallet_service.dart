import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletService {
  WalletService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  static const int minTopUpCents = 2000; // RM20
  static const int minRemainCents = 2000; // RM20 (must keep RM20 after withdraw)

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not logged in');
    return u.uid;
  }

  DocumentReference<Map<String, dynamic>> get userRef => _db.collection('users').doc(_uid);
  CollectionReference<Map<String, dynamic>> get txRoot => _db.collection('walletTransactions');

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream() => userRef.snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> latestTxStream({int limit = 5}) {
    return txRoot
        .where('uid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> allTxStream() {
    return txRoot
        .where('uid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>> createTopUpIntent({required int amountCents}) async {
    if (amountCents < minTopUpCents) {
      throw ArgumentError('Minimum top up is RM20');
    }
    final callable = _functions.httpsCallable('createTopUpIntent');
    final res = await callable.call({'amountCents': amountCents});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> confirmTopUp({required String paymentIntentId}) async {
    final callable = _functions.httpsCallable('confirmTopUp');
    final res = await callable.call({'paymentIntentId': paymentIntentId});
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Simulated withdraw:
  /// - balance must be > RM20
  /// - remaining must be >= RM20
  /// - write walletTransactions immediately as success
  Future<void> requestWithdraw({
    required int amountCents,
    required String bank,
    required String accountNumber,
  }) async {
    if (amountCents <= 0) throw ArgumentError('Invalid withdraw amount');

    await _db.runTransaction((t) async {
      final snap = await t.get(userRef);
      if (!snap.exists) throw StateError('User not found');

      final data = snap.data() ?? {};
      final balanceCents = (data['walletBalance'] ?? 0) as int;

      if (balanceCents <= minRemainCents) {
        throw StateError('Balance must be more than RM20.00 to withdraw');
      }

      final remain = balanceCents - amountCents;
      if (remain < minRemainCents) {
        throw StateError('You must keep at least RM20.00 after withdraw');
      }

      // Update balance
      t.update(userRef, {
        'walletBalance': remain,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create tx
      final txDoc = txRoot.doc();
      t.set(txDoc, {
        'uid': _uid,
        'type': 'withdraw',
        'method': 'withdraw',
        'title': 'Withdraw',
        'amountCents': -amountCents, // debit
        'status': 'success',
        'createdAt': FieldValue.serverTimestamp(),
        'ref': {
          'bank': bank,
          'accountNumberMasked': _maskAcc(accountNumber),
        },
      });
    });
  }

  String _maskAcc(String acc) {
    final s = acc.trim();
    if (s.length <= 4) return s;
    final last4 = s.substring(s.length - 4);
    return '**** **** **** $last4';
  }
}
