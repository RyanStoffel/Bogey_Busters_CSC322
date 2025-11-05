import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import '../firebase_options.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Configure client ID for iOS/macOS (Android uses default from google-services.json)
    clientId:
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)
        ? DefaultFirebaseOptions.ios.iosClientId
        : null,
    scopes: ['email', 'profile'],
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

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

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Check if tokens are available
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw 'Failed to obtain Google authentication tokens. Please try again.';
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      // Handle account-exists-with-different-credential error
      if (e.code == 'account-exists-with-different-credential') {
        // Get the list of sign-in methods for the email
        final email = e.email;
        if (email != null) {
          final providers = await _auth.fetchSignInMethodsForEmail(email);
          throw 'An account already exists with email $email. Please sign in using ${providers.first} first, then you can link your Google account.';
        } else {
          throw 'An account already exists with this email address using a different sign-in method.';
        }
      }
      throw _handleAuthException(e);
    } catch (e) {
      // Handle specific Google Sign-In errors
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('sign_in_canceled') ||
          errorMessage.contains('sign_in_cancelled')) {
        return null; // User canceled - don't throw error
      }
      throw 'An error occurred during Google sign-in: ${e.toString()}';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
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
        final isAdmin = userEmail == 'ryanstoffel44@gmail.com';
        
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
        // If document exists, ensure admin status is set for the specified email
        final userEmail = currentUser.email ?? user.email ?? '';
        if (userEmail == 'ryanstoffel44@gmail.com') {
          await docRef.update({'isAdmin': true});
        }
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

  // Link Google account to current user
  Future<User?> linkGoogleAccount() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'No user is currently signed in. Please sign in first.';
      }

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Link the credential to the current user
      final UserCredential result = await currentUser.linkWithCredential(
        credential,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('sign_in_canceled') ||
          errorMessage.contains('sign_in_cancelled')) {
        return null; // User canceled - don't throw error
      }
      throw 'An error occurred while linking Google account: ${e.toString()}';
    }
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
