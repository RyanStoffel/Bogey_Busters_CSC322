import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Golf Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const SplashScreen(), // Start with splash screen
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.green,
              ),
            ),
          );
        }

        // If user is logged in
        if (snapshot.hasData) {
          final user = snapshot.data!;
          
          // Check if email is verified
          if (!user.emailVerified) {
            // Show verify email screen, don't sign them out
            return VerifyEmailScreen(email: user.email ?? '');
          }

          // Email is verified, check onboarding status
          return FutureBuilder<bool>(
            future: authService.hasCompletedOnboarding(),
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      color: Colors.green,
                    ),
                  ),
                );
              }

              final hasCompletedOnboarding = onboardingSnapshot.data ?? false;
              
              return hasCompletedOnboarding
                  ? const HomeScreen()
                  : const OnboardingScreen();
            },
          );
        }

        // User is not logged in, show auth screen
        return const AuthScreen();
      },
    );
  }
}