import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_errors.dart';
import '../utils/validators.dart';
import '../widgets/error_list.dart';
import '../widgets/primary_button.dart';
import '../widgets/primary_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _auth = AuthService();
  final _emailCtrl = TextEditingController();

  bool _loading = false;
  List<String> _errors = [];

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSendReset() async {
    FocusScope.of(context).unfocus();
    setState(() => _errors = []);

    final errs = Validators.validateForgotPasswordAll(email: _emailCtrl.text);
    if (errs.isNotEmpty) {
      setState(() => _errors = errs);
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.resetPassword(_emailCtrl.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset link sent! Check your email.')),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => _errors = [AppErrors.friendly(e)]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF1E73FF);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 12),

              if (_errors.isNotEmpty) ...[
                ErrorList(_errors),
                const SizedBox(height: 12),
              ],

              PrimaryTextField(
                controller: _emailCtrl,
                label: 'TARUMT Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),

              PrimaryButton(
                text: 'Send Reset Link',
                loading: _loading,
                onPressed: _onSendReset,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
