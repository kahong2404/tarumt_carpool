import 'package:flutter/material.dart';
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

  Future<void> submit() async {
    if (!canWithdrawAtAll) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Balance must be more than RM20.00 to withdraw')),
      );
      return;
    }
    if (amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    if (_accCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill account number')),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Withdraw success: RM ${(amountCents / 100).toStringAsFixed(2)}')),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Withdraw failed: $e')),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current balance: RM ${balanceRm.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Rule: balance must be > RM20.00 and must keep RM20.00 after withdraw.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _Field(label: 'Amount (RM)', controller: _amountCtrl, hint: 'e.g. 50'),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          _Field(label: 'Account Number', controller: _accCtrl, hint: 'e.g. 1234567890'),
          const SizedBox(height: 18),

          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loading ? null : submit,
              child: _loading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator())
                  : const Text('Submit Withdraw', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  const _Field({required this.label, required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: label.contains('Amount') ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
