import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:golf_tracker_app/models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // Create or update user profile
  Future<void> createUserProfile(User user) async {
    // Set admin status for the specified email
    final userData = user.toJson();
    await _db.collection('users').doc(user.uid).set(userData);
  }
  
  // Check if a user is an admin
  Future<bool> isUserAdmin(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data();
      return data?['isAdmin'] as bool? ?? false;
    }
    return false;
  }

  // Get user profile
  Future<User?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return User.fromJson(doc.data()!);
    }
    return null;
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  // Delete user profile
  Future<void> deleteUserProfile(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }
}
