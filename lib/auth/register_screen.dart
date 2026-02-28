import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tarumt_carpool/services/auth_service.dart';
import 'package:tarumt_carpool/utils/validators.dart';
import 'package:tarumt_carpool/utils/app_errors.dart';
import 'package:tarumt_carpool/widgets/error_list.dart';
import 'package:tarumt_carpool/widgets/primary_button.dart';
import 'package:tarumt_carpool/widgets/primary_text_field.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = AuthService();

  int _roleIndex = 0; // 0 = Rider, 1 = Driver
  String get _role => _roleIndex == 0 ? 'rider' : 'driver';

  final _emailCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();

  bool _pwHidden = true;  // hide show password
  bool _pw2Hidden = true; // hide show confirm password
  bool _loading = false; // show loading on button
  List<String> _errors = []; //stores validation and backend error

  final Color brandBlue = const Color(0xFF1E73FF); //the,e Color

  @override
  void dispose() { // dispose means after leave this page, flutter fress memory from controllers
    _emailCtrl.dispose();
    _userIdCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    FocusScope.of(context).unfocus(); // unfocus the textField
    setState(() => _errors = []); // clear the the old error

    final errs = Validators.validateRegisterUI(
      email: _emailCtrl.text,
      userId: _userIdCtrl.text,
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
      password: _pwCtrl.text,
      confirmPassword: _pw2Ctrl.text,
    );

    if (errs.isNotEmpty) {
      setState(() => _errors = errs); //  store the error and rebuid the UI (Flutter runs build() again)
      return; // exit the SignUp function
    }

    setState(() => _loading = true); //show loading in the button
    try {
      await _auth.register(
        role: _role,
        userId: _userIdCtrl.text,
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        password: _pwCtrl.text,
      );

      if (!mounted) return; // If the screen is already closed, stop this register function now. Don’t show snackbar, don’t navigate, don’t update UI

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully.')),
      );  // Show success message after register

      Future.delayed(const Duration(milliseconds: 200), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ); //  go to login with delay 2 seconds
      });
    } catch (e) {
      setState(() => _errors = AppErrors.friendlyList(e));
      //set triggers UI rebuild so the user sees the error
    } finally {
      if (mounted) setState(() => _loading = false); //stop showing loading on the button
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
                  child: Transform.scale(
                    scale: 1.40,
                    child: Image.asset(
                      'assets/logo/logo_circle.png',
                      fit: BoxFit.cover,
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
                controller: _userIdCtrl,
                label: 'Student / Staff ID',
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
                label: 'Phone Number',
                keyboardType: TextInputType.phone,
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
