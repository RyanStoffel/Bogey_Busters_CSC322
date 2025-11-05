import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(Duration(seconds: 2));

    if (!mounted) return;

    final user = _authService.currentUser;
    
    if (user != null) {
      // Check if user has completed onboarding
      final hasCompletedOnboarding = await _authService.hasCompletedOnboarding();
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => hasCompletedOnboarding 
            ? const HomeScreen() 
            : const OnboardingScreen(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.golf_course_rounded,
              size: 120,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            Text(
              'Bogey Busters',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}

