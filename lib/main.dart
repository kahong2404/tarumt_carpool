import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'firebase_options.dart';

// screens
import 'auth/login_screen.dart';
import 'auth/after_login_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Android may auto-init Firebase -> calling initializeApp again can throw duplicate-app.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  // ✅ Stripe plugin is NOT supported on Web
  if (!kIsWeb) {
    Stripe.publishableKey =
    "pk_test_51SyGJ7QrL7OrMixX6Sfx0hTMnXBvx2kQqBL0QutcUhS7DYUY8e0VR7KnlxoSiSGXlWQgrctaGbzb7AVtKT3L7ILC00XypWvA50";
    await Stripe.instance.applySettings();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const brandBlue = Color(0xFF1E73FF);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ✅ GLOBAL THEME (this controls default button/text colors like "Select")
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandBlue,
          primary: brandBlue,
        ),

        // Optional: make TextButton/OutlinedButton "Select" always blue
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: brandBlue,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: brandBlue,
          ),
        ),
      ),

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // ✅ already logged in -> go to router (rider/driver/admin)
          if (snap.data != null) {
            return AfterLoginRouter();
          }

          // ✅ not logged in -> go login
          return const LoginScreen();
        },
      ),
    );
  }
}