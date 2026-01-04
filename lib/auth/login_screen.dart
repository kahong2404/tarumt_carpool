import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../repositories/user_repository.dart';
import '../screens/admin_home_page.dart';
import '../screens/rider_home_page.dart';
import '../screens/driver_home_page.dart';
import 'auth_service.dart';
import '../widgets/error_text.dart';
import '../widgets/primary_button.dart';
import '../widgets/primary_text_field.dart';
import 'register_screen.dart';
import '../app_state.dart';
import '../models/app_user.dart';




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
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  bool _isTarumtEmail(String email) {
    final e = email.trim().toLowerCase();
    return e.endsWith('@student.tarc.edu.my') || e.endsWith('@tarc.edu.my');
  }

  String? _validate() {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;

    if (email.isEmpty || pw.isEmpty) return 'Please fill in all fields.';
    if (!_isTarumtEmail(email)) return 'Please use a valid TARUMT email.';
    if (pw.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('user-not-found')) return 'No account found for this email.';
    if (msg.contains('wrong-password')) return 'Incorrect password.';
    if (msg.contains('invalid-email')) return 'Invalid email format.';
    if (msg.contains('network-request-failed')) return 'Network error. Please try again.';
    return 'Login failed. Please try again.';
  }

  Future<void> _onLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    final v = _validate();
    if (v != null) {
      setState(() => _error = v);
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.login(
        email: _emailCtrl.text,
        password: _pwCtrl.text,
      );

      if (!mounted) return;

      // ✅ After login success, go to a placeholder Home for now
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AfterLoginRouter()),
      );
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color brandBlue = const Color(0xFF1E73FF);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            children: [
              const SizedBox(height: 18),

              // Logo
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brandBlue,
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

              const SizedBox(height: 12),

              // Go to register
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

/// Temporary screen after login (we will replace later)
class AfterLoginRouter extends StatelessWidget {
  AfterLoginRouter({super.key});

  final UserRepository _users = UserRepository();

  Future<AppUser> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');

    final user = await _users.getUser(uid);

    // 🔥 STORE in app state
    AppState().currentUser = user;

    return user;
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser>(
      future: _loadUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final user = snapshot.data!;
        final role = user.role;


        if (role == 'admin') {
          return const DriverHomePage();
        } else if (role == 'driver') {
          return const DriverHomePage();
        } else {
          return const RiderHomePage();
        }
      },
    );
  }
}

