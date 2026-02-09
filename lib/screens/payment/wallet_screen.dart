// lib/screens/wallet/wallet_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/payment/wallet_service.dart';
import 'wallet_topup_screen.dart';
import 'wallet_withdraw_screen.dart';
import 'wallet_transactions_screen.dart';
import 'wallet_transaction_detail_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  static const primary = Color(0xFF1E73FF);

  @override
  Widget build(BuildContext context) {
    final wallet = WalletService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Wallet'),
        centerTitle: true,
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: wallet.userStream(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'Error: ${snap.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final data = snap.data?.data() ?? {};

              // ✅ Firestore key is walletBalance (cents int)
              final balanceCents = (data['walletBalance'] ?? 0) as int;

              return _BalanceCard(
                balanceCents: balanceCents,
                onTopUp: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletTopUpScreen()),
                ),
                onWithdraw: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WalletWithdrawScreen(currentBalanceCents: balanceCents),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _TransactionsCard(
            txStream: wallet.latestTxStream(limit: 5),
            onViewAll: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WalletTransactionsScreen()),
            ),
            onTapTx: (doc) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WalletTransactionDetailScreen(txDoc: doc),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final int balanceCents;
  final VoidCallback onTopUp;
  final VoidCallback onWithdraw;

  const _BalanceCard({
    required this.balanceCents,
    required this.onTopUp,
    required this.onWithdraw,
  });

  static const primary = Color(0xFF1E73FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RM ${(balanceCents / 100).toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: onTopUp,
                    child: const Text('+ Top Up'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: const BorderSide(color: primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: onWithdraw,
                    child: const Text('Withdraw'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Top up min RM20 • Must keep RM20 after withdraw',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _TransactionsCard extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> txStream;
  final VoidCallback onViewAll;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) onTapTx;

  const _TransactionsCard({
    required this.txStream,
    required this.onViewAll,
    required this.onTapTx,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Wallet Transactions',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: onViewAll,
                icon: const Icon(Icons.receipt_long, color: Colors.black54),
              ),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: txStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'Error: ${snap.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                );
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('No transactions yet.'),
                );
              }

              return Column(
                children: docs.map((d) => _TxRow(doc: d, onTap: () => onTapTx(d))).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onTap;

  const _TxRow({required this.doc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();

    final title = (data['title'] ?? data['type'] ?? 'Transaction').toString();
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

    final isMinus = amountCents < 0;
    final amountText =
        '${isMinus ? '-' : '+'} RM ${(amountCents.abs() / 100).toStringAsFixed(2)}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),

                  // ✅ only date time, no status
                  Text(
                    dateText,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Text(
              amountText,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isMinus ? Colors.black87 : Colors.green[700],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.black38, size: 18),
          ],
        ),
      ),
    );
  }
}
