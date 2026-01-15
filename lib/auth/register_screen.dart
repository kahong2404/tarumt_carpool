import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../utils/app_errors.dart';
import '../widgets/error_list.dart';
import '../widgets/primary_button.dart';
import '../widgets/primary_text_field.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = AuthService();

  int _roleIndex = 0; // 0 Rider, 1 Driver
  String get _role => _roleIndex == 0 ? 'rider' : 'driver';

  final _emailCtrl = TextEditingController();
  final _staffIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();

  bool _pwHidden = true;
  bool _pw2Hidden = true;
  bool _loading = false;
  List<String> _errors = [];

  final Color brandBlue = const Color(0xFF1E73FF);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _staffIdCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    FocusScope.of(context).unfocus();
    setState(() => _errors = []);

    final errs = Validators.validateRegisterAll(
      email: _emailCtrl.text,
      staffId: _staffIdCtrl.text,
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
      password: _pwCtrl.text,
      confirmPassword: _pw2Ctrl.text,
    );

    if (errs.isNotEmpty) {
      setState(() => _errors = errs);
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.register(
        role: _role,
        staffId: _staffIdCtrl.text,
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        password: _pwCtrl.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );

      Future.delayed(const Duration(milliseconds: 600), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brandBlue.withOpacity(0.10),
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

              const SizedBox(height: 8),
              const Text('Sign Up',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),

              CupertinoSlidingSegmentedControl<int>(
                groupValue: _roleIndex,
                backgroundColor: Colors.white,
                thumbColor: brandBlue,
                children: {
                  0: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Text(
                      'RIDER',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _roleIndex == 0 ? Colors.white : brandBlue,
                      ),
                    ),
                  ),
                  1: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Text(
                      'DRIVER',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _roleIndex == 1 ? Colors.white : brandBlue,
                      ),
                    ),
                  ),
                },
                onValueChanged: (v) {
                  if (v == null) return;
                  setState(() => _roleIndex = v);
                },
              ),

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
                controller: _staffIdCtrl,
                label: 'Student / Staff ID (7 digits)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              PrimaryTextField(
                controller: _nameCtrl,
                label: 'Full Name',
              ),
              const SizedBox(height: 12),

              PrimaryTextField(
                controller: _phoneCtrl,
                label: 'Phone Number (Malaysia)',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              PrimaryTextField(
                controller: _pwCtrl,
                label: 'Password (12+ strong)',
                obscureText: _pwHidden,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _pwHidden = !_pwHidden),
                  icon: Icon(_pwHidden ? Icons.visibility_off : Icons.visibility),
                ),
              ),
              const SizedBox(height: 12),

              PrimaryTextField(
                controller: _pw2Ctrl,
                label: 'Confirm Password',
                obscureText: _pw2Hidden,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _pw2Hidden = !_pw2Hidden),
                  icon: Icon(_pw2Hidden ? Icons.visibility_off : Icons.visibility),
                ),
              ),

              const SizedBox(height: 18),

              PrimaryButton(
                text: 'Sign Up',
                loading: _loading,
                onPressed: _onSignUp,
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('Already have an account? Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
