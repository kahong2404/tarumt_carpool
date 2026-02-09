import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WalletTransactionDetailScreen extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> txDoc;
  const WalletTransactionDetailScreen({super.key, required this.txDoc});

  static const primary = Color(0xFF1E73FF);

  @override
  Widget build(BuildContext context) {
    final data = txDoc.data();

    final type = (data['type'] ?? '-').toString();
    final method = (data['method'] ?? '-').toString();
    final amountCents = (data['amountCents'] ?? 0) as int;

    final ts = data['createdAt'];
    final createdAt = ts is Timestamp ? ts.toDate() : null;
    final dateText = createdAt == null
        ? '-'
        : '${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}/'
        '${createdAt.year} '
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}';

    final isDebit = amountCents < 0;
    final amountText = '${isDebit ? '-' : '+'}RM ${(amountCents.abs() / 100).toStringAsFixed(2)}';

    final ref = data['ref'];
    final refMap = ref is Map ? ref.cast<String, dynamic>() : <String, dynamic>{};

    final rows = <MapEntry<String, String>>[];

    rows.add(MapEntry('Transaction Type', _prettyType(type, method)));
    rows.add(MapEntry('Date/Time', dateText)); // ✅ keep date/time only (no status)

    // Reference fields
    final bank = refMap['bank']?.toString();
    final accMasked = refMap['accountNumberMasked']?.toString();
    final pi = refMap['paymentIntentId']?.toString();
    final methods = refMap['methods'];

    if (bank != null && bank.isNotEmpty) rows.add(MapEntry('Bank', bank));
    if (accMasked != null && accMasked.isNotEmpty) rows.add(MapEntry('Account', accMasked));
    if (pi != null && pi.isNotEmpty) rows.add(MapEntry('Wallet Ref', pi));

    // ✅ If methods has [card, link] => show only Card
    if (methods is List && methods.isNotEmpty) {
      final list = methods.map((e) => e.toString()).toList();
      final shown = list.contains('card') ? ['Card'] : list.map(_cap).toList();
      rows.add(MapEntry('Method', shown.join(', ')));
    }

    rows.add(MapEntry('Transaction No.', txDoc.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            amountText,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: isDebit ? Colors.black87 : primary,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          ...rows.map((e) => _row(e.key, e.value)),
        ],
      ),
    );
  }

  static String _prettyType(String type, String method) {
    if (type == 'topup') return 'Top Up (Card)';
    if (type == 'withdraw') return 'Withdraw';
    if (type == 'ride_payment') return 'Ride Payment';
    if (type == 'earning') return 'Earning';
    if (type == 'refund') return 'Refund';
    return '${type.toUpperCase()} (${method.toUpperCase()})';
  }

  static String _cap(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _row(String left, String right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(left, style: const TextStyle(color: Colors.black54)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              right,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
