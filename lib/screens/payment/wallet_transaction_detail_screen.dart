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

    // ✅ ONE LINE FORMAT: 01:35 1 March 2026
    final dateText = createdAt == null ? '-' : _formatTimeThenDate(createdAt);

    final isDebit = amountCents < 0;
    final amountText =
        '${isDebit ? '-' : '+'}RM ${(amountCents.abs() / 100).toStringAsFixed(2)}';

    final ref = data['ref'];
    final refMap = ref is Map ? ref.cast<String, dynamic>() : <String, dynamic>{};

    final rows = <MapEntry<String, String>>[];

    rows.add(MapEntry('Transaction Type', _prettyType(type, method)));
    rows.add(MapEntry('Date/Time', dateText));

    final bank = refMap['bank']?.toString();
    final accMasked = refMap['accountNumberMasked']?.toString();
    final pi = refMap['paymentIntentId']?.toString();
    final methods = refMap['methods'];

    if (bank != null && bank.isNotEmpty) rows.add(MapEntry('Bank', bank));
    if (accMasked != null && accMasked.isNotEmpty) {
      rows.add(MapEntry('Account', accMasked));
    }
    if (pi != null && pi.isNotEmpty) rows.add(MapEntry('Wallet Ref', pi));

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

  // ✅ 01:35 1 March 2026
  static String _formatTimeThenDate(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString();
    final month = _monthName(dt.month);
    final year = dt.year.toString();
    return '$hh:$mm $day $month $year';
  }

  static String _monthName(int m) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[m - 1];
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