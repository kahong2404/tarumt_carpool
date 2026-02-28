import 'package:flutter/material.dart';
import 'package:tarumt_carpool/widgets/layout/app_scaffold.dart';
import 'package:tarumt_carpool/widgets/primary_button.dart';
import 'package:tarumt_carpool/widgets/primary_text_field.dart';

import '../../services/payment/wallet_service.dart';

class WalletWithdrawScreen extends StatefulWidget {
  final int currentBalanceCents;
  const WalletWithdrawScreen({super.key, required this.currentBalanceCents});

  @override
  State<WalletWithdrawScreen> createState() => _WalletWithdrawScreenState();
}

class _WalletWithdrawScreenState extends State<WalletWithdrawScreen> {
  static const primary = Color(0xFF1E73FF);
  static const int minRemainCents = 2000; // RM20

  final _wallet = WalletService();
  final _amountCtrl = TextEditingController();
  final _accCtrl = TextEditingController();

  String _bank = 'Maybank';
  bool _loading = false;

  int get amountCents {
    final rm = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    return (rm * 100).round();
  }

  bool get canWithdrawAtAll => widget.currentBalanceCents > minRemainCents;

  String _friendlyError(Object e) {
    var msg = e.toString().trim();

    const prefixes = [
      'Bad state: ',
      'Exception: ',
      'FirebaseException: ',
    ];
    for (final p in prefixes) {
      if (msg.startsWith(p)) msg = msg.substring(p.length);
    }

    if (msg.isEmpty) return 'Withdrawal request failed. Please try again.';
    return msg;
  }

  Future<void> submit() async {
    if (!canWithdrawAtAll) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Balance must be more than RM20.00 to withdraw.')),
      );
      return;
    }

    if (amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid withdrawal amount.')),
      );
      return;
    }

    // ✅ Prevent "Bad state" by validating remaining balance locally
    final remain = widget.currentBalanceCents - amountCents;
    if (remain < minRemainCents) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must keep at least RM20.00 after withdrawal.')),
      );
      return;
    }

    if (_accCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your account number.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _wallet.requestWithdraw(
        amountCents: amountCents,
        bank: _bank,
        accountNumber: _accCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Withdrawal submitted: RM ${(amountCents / 100).toStringAsFixed(2)}',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _accCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balanceRm = widget.currentBalanceCents / 100.0;

    return AppScaffold(
      title: 'Withdraw',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  color: Colors.black.withOpacity(0.06),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current balance:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'RM ${balanceRm.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'A minimum wallet balance of RM20.00 must be maintained after withdrawal.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          PrimaryTextField(
            controller: _amountCtrl,
            label: 'Amount (RM)',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),

          const Text('Bank', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _bank,
            items: const [
              DropdownMenuItem(value: 'Maybank', child: Text('Maybank')),
              DropdownMenuItem(value: 'CIMB', child: Text('CIMB')),
              DropdownMenuItem(value: 'Public Bank', child: Text('Public Bank')),
              DropdownMenuItem(value: 'RHB', child: Text('RHB')),
              DropdownMenuItem(value: 'Hong Leong', child: Text('Hong Leong')),
            ],
            onChanged: (v) => setState(() => _bank = v ?? _bank),
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          PrimaryTextField(
            controller: _accCtrl,
            label: 'Account Number',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),

          PrimaryButton(
            text: 'Withdraw',
            loading: _loading,
            onPressed: _loading ? null : submit,
          ),
        ],
      ),
    );
  }
}