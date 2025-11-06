import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  //////////////////////////
  /// Instance Variables ///
  //////////////////////////

  final AuthService _authService = AuthService();
  bool isChecking = false;
  bool isVerified = false;
  bool showResendButton = false;
  bool isResending = false;
  int _secondsElapsed = 0;
  Timer? _timer;
  Timer? _resendTimer;

  //////////////////////
  /// Helper Methods ///
  //////////////////////

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  //////////////////////////////
  /// Verification Methods ///
  //////////////////////////////

  Future<void> _checkVerificationStatus() async {
    if (isVerified || !mounted) return;

    setState(() => isChecking = true);

    try {
      await _authService.reloadUser();
      if (!mounted) return;
      
      final currentUser = _authService.currentUser;

      if (currentUser != null && currentUser.emailVerified) {
        if (!mounted) return;
        
        setState(() {
          isVerified = true;
          isChecking = false;
        });
        _timer?.cancel();
        _resendTimer?.cancel();
        _showMessage('Email verified successfully!');
        
        await Future.delayed(Duration(seconds: 2));
        
        if (!mounted) return;
        
        context.go('/onboarding');
      } else {
        if (mounted) {
          setState(() => isChecking = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isChecking = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() {
      isResending = true;
      showResendButton = false;
      _secondsElapsed = 0;
    });

    try {
      await _authService.sendEmailVerification();
      _showMessage('Verification email sent! Please check your inbox.');
      _startResendTimer();
    } catch (e) {
      _showMessage(e.toString(), isError: true);
      setState(() => showResendButton = true);
    } finally {
      setState(() => isResending = false);
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _secondsElapsed = 0;
    _resendTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
        if (_secondsElapsed >= 30) {
          showResendButton = true;
          timer.cancel();
        }
      });
    });
  }

  void _startVerificationCheck() {
    _checkVerificationStatus();
    _timer = Timer.periodic(Duration(seconds: 3), (_) {
      _checkVerificationStatus();
    });
  }

  ////////////////////////////
  /// Widget Build Methods ///
  ////////////////////////////

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _startVerificationCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeader(),
              const SizedBox(height: 48),
              if (isVerified)
                _buildVerifiedState()
              else
                _buildPendingState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(Icons.golf_course_rounded, size: 100, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          'Bogey Busters',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildPendingState() {
    return Column(
      children: [
        Icon(
          Icons.mail_outline,
          size: 80,
          color: Colors.grey[600],
        ),
        const SizedBox(height: 24),
        Text(
          'Verify Your Email',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'We\'ve sent a verification email to',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        Text(
          widget.email,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Please check your inbox and click the verification link.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        if (showResendButton) ...[
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isResending ? null : _resendVerificationEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isResending
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Resend Verification Email',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ] else if (!isResending) ...[
          const SizedBox(height: 32),
          Text(
            'Resend email available in ${30 - _secondsElapsed} seconds',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => context.go('/auth'),
          child: Text(
            'Back to Login',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifiedState() {
    return Column(
      children: [
        Icon(
          Icons.check_circle,
          size: 80,
          color: Colors.green,
        ),
        const SizedBox(height: 24),
        Text(
          'Email Verified!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Your email has been successfully verified.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => context.go('/onboarding'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

