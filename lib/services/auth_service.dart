import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _isLoggedInKey = 'isLoggedIn';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, value);
  }

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await setLoggedIn(true);
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign up with email and password
  Future<User?> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await Future.wait([_auth.signOut()]);
    await setLoggedIn(false);
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Create user document in Firestore (only if it doesn't exist)
  Future<void> createUserDocument(User user) async {
    try {
      // Use currentUser to ensure we have the authenticated context
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'No authenticated user found';
      }

      // Ensure auth token is ready by getting a fresh token
      await currentUser.getIdToken(true);

      // Small delay to ensure token propagation
      await Future.delayed(Duration(milliseconds: 300));

      final docRef = _firestore.collection('users').doc(currentUser.uid);

      // Try to check if document exists, but handle permission error gracefully
      bool documentExists = false;
      try {
        final docSnapshot = await docRef.get();
        documentExists = docSnapshot.exists;
      } catch (e) {
        // If we can't read (permission denied), assume it doesn't exist and try to create
        // The create will fail if it already exists, which is fine
        documentExists = false;
      }

      // Only create if document doesn't exist
      if (!documentExists) {
        final userEmail = currentUser.email ?? user.email ?? '';
        // Remove hard-coded admin special-case. Default new users to non-admin.
        final isAdmin = false;

        await docRef.set({
          'uid': currentUser.uid,
          'email': userEmail,
          'displayName': currentUser.displayName ?? user.displayName,
          'photoURL': currentUser.photoURL ?? user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'emailVerified': currentUser.emailVerified,
          'onboardingCompleted': false,
          'isAdmin': isAdmin,
        });
      } else {
        // If document exists, do not automatically change admin status here.
        // Admins should be managed explicitly elsewhere (Firestore console or admin APIs).
      }
    } catch (e) {
      throw 'Failed to create user document: ${e.toString()}';
    }
  }

  // Update user document in Firestore
  Future<void> updateUserDocument(Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in.';
      }

      await _firestore.collection('users').doc(user.uid).update(data);
    } catch (e) {
      throw 'Failed to update user document: ${e.toString()}';
    }
  }

  // Upload profile picture to Firebase Storage
  Future<String?> uploadProfilePicture(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in.';
      }

      // Create a reference to the storage location
      final ref = _storage.ref().child('profile_pictures/${user.uid}.jpg');

      // Upload the file
      await ref.putFile(imageFile);

      // Get the download URL
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw 'Failed to upload profile picture: ${e.toString()}';
    }
  }

  // Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final data = doc.data();
      return data?['onboardingCompleted'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      } else if (user == null) {
        throw 'No user is currently signed in.';
      } else if (user.emailVerified) {
        throw 'Email is already verified.';
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Reload user to check email verification status
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  // Delete account
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Handle Firebase Auth exceptions and return user-friendly messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password is too weak.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'credential-already-in-use':
        return 'This Google account is already linked to another user.';
      case 'provider-already-linked':
        return 'This Google account is already linked to your account.';
      case 'invalid-credential':
        return 'The Google credential is not valid. Please try again.';
      default:
        return 'An error occurred: ${e.message ?? e.code}';
    }
  }
}
