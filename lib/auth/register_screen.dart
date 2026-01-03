import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../widgets/error_text.dart';
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
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dec(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      suffixIcon: suffixIcon,
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            children: [
              const SizedBox(height: 18),
              CircleAvatar(
                radius: 28, // slightly bigger for logo
                backgroundColor: Colors.transparent,
                child: ClipOval(
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text('TARUMT Carpooling', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              const Text('Sign Up', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),

              CupertinoSlidingSegmentedControl<int>(
                groupValue: _roleIndex,
                children: const {
                  0: Padding(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Text('RIDER')),
                  1: Padding(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Text('DRIVER')),
                },
                onValueChanged: (v) {
                  if (v == null) return;
                  setState(() => _roleIndex = v);
                },
              ),

              const SizedBox(height: 18),

              if (_error != null) ...[
                ErrorText(_error!),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('TARUMT Email'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _staffIdCtrl,
                decoration: _dec('Student / Staff ID'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: _dec('Phone Number'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _pwCtrl,
                obscureText: _pwHidden,
                decoration: _dec(
                  'Password',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _pwHidden = !_pwHidden),
                    icon: Icon(_pwHidden ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _pw2Ctrl,
                obscureText: _pw2Hidden,
                decoration: _dec(
                  'Confirm Password',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _pw2Hidden = !_pw2Hidden),
                    icon: Icon(_pw2Hidden ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _onSignUp,
                  child: _loading
                      ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Sign Up'),
                ),
              ),

              //Remember to delete this linking to the driver homepage
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DriverHomePage(),
                      ),
                    );
                  },
                  child: const Text(
                    'Go to Driver Home Page',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
