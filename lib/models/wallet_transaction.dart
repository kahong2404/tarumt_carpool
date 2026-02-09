import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransaction {
  final String id;
  final String uid;
  final String type;   // topup | withdraw
  final String method; // card | withdraw
  final int amountCents; // + credit, - debit
  final String status; // success | pending | failed
  final String title;  // Top up | Withdraw
  final DateTime? createdAt;
  final Map<String, dynamic> ref;

  WalletTransaction({
    required this.id,
    required this.uid,
    required this.type,
    required this.method,
    required this.amountCents,
    required this.status,
    required this.title,
    required this.createdAt,
    required this.ref,
  });

  factory WalletTransaction.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final ts = d['createdAt'];
    return WalletTransaction(
      id: doc.id,
      uid: (d['uid'] ?? '').toString(),
      type: (d['type'] ?? '').toString(),
      method: (d['method'] ?? '').toString(),
      amountCents: (d['amountCents'] ?? 0) as int,
      status: (d['status'] ?? 'success').toString(),
      title: (d['title'] ?? d['type'] ?? 'Transaction').toString(),
      createdAt: ts is Timestamp ? ts.toDate() : null,
      ref: (d['ref'] is Map) ? Map<String, dynamic>.from(d['ref'] as Map) : <String, dynamic>{},
    );
  }
}
