import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:tarumt_carpool/widgets/layout/app_scaffold.dart';

import '../../services/payment/wallet_service.dart';
import 'package:tarumt_carpool/widgets/primary_button.dart';
import 'package:tarumt_carpool/widgets/primary_text_field.dart';

class WalletTopUpScreen extends StatefulWidget {
  const WalletTopUpScreen({super.key});

  @override
  State<WalletTopUpScreen> createState() => _WalletTopUpScreenState();
}

class _WalletTopUpScreenState extends State<WalletTopUpScreen> {
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
      final res = await _wallet.createTopUpIntent(amountCents: amountCents);
      final clientSecret = (res['clientSecret'] ?? '').toString();
      final paymentIntentId = (res['paymentIntentId'] ?? '').toString();

      if (clientSecret.isEmpty || paymentIntentId.isEmpty) {
        throw StateError('Missing clientSecret/paymentIntentId from server');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'TARUMT Carpool',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      await _wallet.confirmTopUp(paymentIntentId: paymentIntentId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Top up successful')),
      );
      Navigator.pop(context);
    } on StripeException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment cancelled/failed: ${e.error.localizedMessage ?? e.toString()}',
          ),
        ),
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
    return AppScaffold(
      title: 'Top Up',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  color: Colors.black.withOpacity(0.06),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [


                PrimaryTextField(
                  controller: _amountCtrl,
                  label: 'Amount (RM)',
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 6),
                const Text(
                  'Minimum top up: RM20',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),

                const SizedBox(height: 14),

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
              ],
            ),
          ),

          const SizedBox(height: 16),

          PrimaryButton(
            text: 'Top Up',
            loading: _loading,
            onPressed: _loading ? null : submit,
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
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}