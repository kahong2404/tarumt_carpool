import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../widgets/error_text.dart';
import '../widgets/primary_button.dart';
import '../widgets/primary_text_field.dart';
import 'login_screen.dart';
import 'driver_homepage.dart';

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
  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();

  bool _pwHidden = true;
  bool _pw2Hidden = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _staffIdCtrl.dispose();
    _phoneCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  bool _isTarumtEmail(String email) {
    final e = email.trim().toLowerCase();
    return e.endsWith('@student.tarc.edu.my') || e.endsWith('@tarc.edu.my');
  }

  String? _validate() {
    final email = _emailCtrl.text.trim();
    final staffId = _staffIdCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pw = _pwCtrl.text;
    final pw2 = _pw2Ctrl.text;

    if (email.isEmpty || staffId.isEmpty || phone.isEmpty || pw.isEmpty || pw2.isEmpty) {
      return 'Please fill in all fields.';
    }
    if (!_isTarumtEmail(email)) {
      return 'Please use a valid TARUMT email.';
    }
    if (pw.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (pw != pw2) {
      return 'Password and Confirm Password do not match.';
    }
    return null;
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('email-already-in-use')) return 'This email is already registered.';
    if (msg.contains('invalid-email')) return 'Invalid email format.';
    if (msg.contains('weak-password')) return 'Password is too weak.';
    if (msg.contains('network-request-failed')) return 'Network error. Please try again.';
    return 'Registration failed. Please try again.';
  }

  Future<void> _onSignUp() async {
    debugPrint('SIGN UP CLICKED');
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    final v = _validate();
    if (v != null) {
      setState(() => _error = v);
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.register(
        role: _role,
        staffId: _staffIdCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        password: _pwCtrl.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );

      Future.delayed(const Duration(milliseconds: 800), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });

    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final Color brandBlue = const Color(0xFF1E73FF);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            children: [
              const SizedBox(height: 18),
              //TARUMT Carpooling logo
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1), // smaller padding = bigger logo
                  child: ClipOval(
                    child: Transform.scale(
                      scale: 1.40, // 🔥 increase this to 1.5 if still small
                      child: Image.asset(
                        'assets/logo/logo_circle.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              //Sign Up text
              const Text('Sign Up', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
            CupertinoSlidingSegmentedControl<int>(
            groupValue: _roleIndex,

            // 🔹 background of the whole control (unselected area)
            backgroundColor: Colors.white,

            // 🔹 color of the selected segment
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
              //error message
              if (_error != null) ...[
                ErrorText(_error!),
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
                label: 'Student / Staff ID',
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('Already have an account? Sign In'),
              ),



              //Remember to delete this linking to the driver homepage
              const SizedBox(height: 12),

              PrimaryButton(
                text: 'Go to Driver Home Page',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DriverHomePage(),
                    ),
                  );
                },
              ),

            ],
          ),
        ),
      ),
    );
  }
}
