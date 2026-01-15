import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_errors.dart';
import '../utils/validators.dart';
import '../widgets/error_list.dart';
import '../widgets/primary_button.dart';
import '../widgets/primary_text_field.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'after_login_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();

  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  bool _pwHidden = true;
  bool _loading = false;
  List<String> _errors = [];

  final Color brandBlue = const Color(0xFF1E73FF);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _errors = []);

    final errs = Validators.validateLoginAll(
      email: _emailCtrl.text,
      password: _pwCtrl.text,
    );

    if (errs.isNotEmpty) {
      setState(() => _errors = errs);
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.login(
        email: _emailCtrl.text,
        password: _pwCtrl.text,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AfterLoginRouter()),
      );
    } catch (e) {
      setState(() => _errors = [AppErrors.friendly(e)]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            children: [
              const SizedBox(height: 18),

              Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1E73FF),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: ClipOval(
                    child: Transform.scale(
                      scale: 1.40,
                      child: Image.asset(
                        'assets/logo/logo_circle.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Text('Sign In',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),

              if (_errors.isNotEmpty) ...[
                ErrorList(_errors),
                const SizedBox(height: 12),
              ],

              PrimaryTextField(
                controller: _emailCtrl,
                label: 'TARUMT Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              PrimaryTextField(
                controller: _pwCtrl,
                label: 'Password',
                obscureText: _pwHidden,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _pwHidden = !_pwHidden),
                  icon: Icon(_pwHidden ? Icons.visibility_off : Icons.visibility),
                ),
              ),

              const SizedBox(height: 18),

              PrimaryButton(
                text: 'Sign In',
                loading: _loading,
                onPressed: _onLogin,
              ),

              const SizedBox(height: 6),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                  );
                },
                child: const Text('Forgot password?'),
              ),

              const SizedBox(height: 6),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: const Text("Don't have an account? Sign Up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
