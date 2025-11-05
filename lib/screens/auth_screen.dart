import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _AuthScreenState();
  }
}

class _AuthScreenState extends State<AuthScreen> {
  //////////////////////////
  /// Instance Variables ///
  //////////////////////////

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool isLoginScreen = true;
  bool showPasswordText = false;
  bool isLoading = false;

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  //////////////////////////////
  /// Authentication Methods ///
  //////////////////////////////

  Future<void> createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (password != confirmPassword) {
      _showMessage('Passwords do not match', isError: true);
      return;
    }

    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters', isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (user != null) {
        // Reload user to ensure auth token is ready for Firestore
        await _authService.reloadUser();
        await _authService.createUserDocument(user);
        await _authService.sendEmailVerification();
        
        _showMessage('Account created! Please check your email for verification.');
      }
    } catch (e) {
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> loginAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final email = emailController.text.trim();
    final password = passwordController.text;

    setState(() => isLoading = true);

    try {
      final user = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (user != null) {
        await _authService.reloadUser();
        // Don't navigate - AuthGate will handle it automatically
        // The StreamBuilder will check email verification and onboarding status
      }
    } catch (e) {
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> navigateToForgotPasswordPage() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      final dialogEmailController = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Reset Password'),
          content: TextField(
            controller: dialogEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email address',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, dialogEmailController.text.trim()),
              
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Send Reset Link'),
            ),
          ],
        ),
      );

      if (result != null && result.isNotEmpty) {
        await _sendPasswordResetEmail(result);
      }
    } else {
      await _sendPasswordResetEmail(email);
    }
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    setState(() => isLoading = true);
    try {
      await _authService.sendPasswordResetEmail(email);
      _showMessage('Password reset email sent! Please check your inbox.');
    } catch (e) {
      _showMessage(e.toString(), isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  ////////////////////////////
  /// Widget Build Methods ///
  ////////////////////////////

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
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
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: emailController,
                  cursorColor: Colors.green,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green, width: 2.0),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2.0),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2.0),
                    ),
                    labelText: 'Email',
                    floatingLabelStyle: TextStyle(color: Colors.green),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  cursorColor: Colors.green,
                  obscureText: !showPasswordText,
                  enabled: !isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green, width: 2.0),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2.0),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2.0),
                    ),
                    labelText: 'Password',
                    floatingLabelStyle: TextStyle(color: Colors.green),
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPasswordText ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: isLoading
                          ? null
                          : () {
                              setState(() {
                                showPasswordText = !showPasswordText;
                              });
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!isLoginScreen) TextFormField(
                  controller: confirmPasswordController,
                  cursorColor: Colors.green,
                  obscureText: !showPasswordText,
                  enabled: !isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green, width: 2.0),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2.0),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2.0),
                    ),
                    labelText: 'Confirm Password',
                    floatingLabelStyle: TextStyle(color: Colors.green),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (isLoginScreen) Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading ? null : navigateToForgotPasswordPage,
                    child: Text('Forgot Password?', style: TextStyle(color: Colors.green)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : (isLoginScreen ? loginAccount : createAccount),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            isLoginScreen ? 'Login' : 'Sign Up',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLoginScreen
                          ? "Don't have an account? "
                          : "Already have an account? ",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              setState(() {
                                isLoginScreen = !isLoginScreen;
                                _formKey.currentState?.reset();
                              });
                            },
                      child: Text(
                        isLoginScreen ? 'Sign Up' : 'Login',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
