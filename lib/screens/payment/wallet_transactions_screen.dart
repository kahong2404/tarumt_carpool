// lib/screens/wallet/wallet_transactions_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tarumt_carpool/widgets/layout/app_scaffold.dart';

import '../../services/payment/wallet_service.dart';
import 'wallet_transaction_detail_screen.dart';

class WalletTransactionsScreen extends StatelessWidget {
  const WalletTransactionsScreen({super.key});

  static const primary = Color(0xFF1E73FF);

  @override
  Widget build(BuildContext context) {
    final wallet = WalletService();

    return AppScaffold(
      title: 'Wallet Transaction',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: wallet.allTxStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error: ${snap.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No transactions yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();

              final title =
              (data['title'] ?? data['type'] ?? 'Transaction').toString();
              final amountCents = (data['amountCents'] ?? 0) as int;

              final ts = data['createdAt'];
              final createdAt = ts is Timestamp ? ts.toDate() : null;

              // ✅ SAME FORMAT AS DETAIL SCREEN: "01:35 13 March 2026"
              final dateText =
              createdAt == null ? '-' : _formatTimeThenDate(createdAt);

              final isMinus = amountCents < 0;
              final amountText =
                  '${isMinus ? '-' : '+'} RM ${(amountCents.abs() / 100).toStringAsFixed(2)}';

              return ListTile(
                title: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(dateText), // ✅ time first, then date
                trailing: Text(
                  amountText,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isMinus ? Colors.black87 : Colors.green[700],
                  ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WalletTransactionDetailScreen(txDoc: d),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ✅ "HH:mm d MMMM yyyy" => e.g. "01:35 13 March 2026"
  static String _formatTimeThenDate(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString(); // no leading zero
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
    if (m < 1 || m > 12) return '-';
    return months[m - 1];
  }
}