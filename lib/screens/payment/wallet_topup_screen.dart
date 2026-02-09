import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../services/payment/wallet_service.dart';

class WalletTopUpScreen extends StatefulWidget {
  const WalletTopUpScreen({super.key});

  @override
  State<WalletTopUpScreen> createState() => _WalletTopUpScreenState();
}

class _WalletTopUpScreenState extends State<WalletTopUpScreen> {
  static const primary = Color(0xFF1E73FF);
  static const int minTopUpRm = 20;

  final _wallet = WalletService();
  final _amountCtrl = TextEditingController(text: '20');

  bool _loading = false;

  int get amountRm => int.tryParse(_amountCtrl.text.trim()) ?? 0;
  int get amountCents => amountRm * 100;

  void setAmount(int rm) => setState(() => _amountCtrl.text = rm.toString());

  Future<void> submit() async {
    if (amountRm < minTopUpRm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum top up amount is RM20')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // 1) Create PaymentIntent from Cloud Function
      final res = await _wallet.createTopUpIntent(amountCents: amountCents);
      final clientSecret = (res['clientSecret'] ?? '').toString();
      final paymentIntentId = (res['paymentIntentId'] ?? '').toString();

      if (clientSecret.isEmpty || paymentIntentId.isEmpty) {
        throw StateError('Missing clientSecret/paymentIntentId from server');
      }

      // 2) Show Stripe Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'TARUMT Carpool',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // 3) Confirm + credit wallet via Cloud Function
      final confirm = await _wallet.confirmTopUp(paymentIntentId: paymentIntentId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Top up success: ${confirm['ok']}')),
      );
      if (mounted) Navigator.pop(context);
    } on StripeException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stripe cancelled/failed: ${e.error.localizedMessage ?? e.toString()}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Top up failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet Top Up'), centerTitle: true),
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
                const Text('Input Top Up Amount', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black12.withOpacity(.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      const Text('RM ', style: TextStyle(fontWeight: FontWeight.w800)),
                      Expanded(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(border: InputBorder.none, hintText: '0'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _QuickAmount(text: 'RM 20', onTap: () => setAmount(20)),
                    _QuickAmount(text: 'RM 50', onTap: () => setAmount(50)),
                    _QuickAmount(text: 'RM 100', onTap: () => setAmount(100)),
                    _QuickAmount(text: 'RM 200', onTap: () => setAmount(200)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Minimum top up: RM20', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _loading ? null : submit,
              child: _loading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator())
                  : const Text('Top Up'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAmount extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _QuickAmount({required this.text, required this.onTap});

  static const primary = Color(0xFF1E73FF);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: primary.withOpacity(.35)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
