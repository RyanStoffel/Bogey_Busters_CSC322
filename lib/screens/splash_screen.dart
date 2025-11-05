import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart'; // Import to access AuthGate

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToAuthGate();
  }

  Future<void> _navigateToAuthGate() async {
    // Show splash screen for 2 seconds
    await Future.delayed(Duration(seconds: 1));
    
    if (!mounted) return;
    
    // Navigate to AuthGate which handles all the routing logic
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthGate()),
    );
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