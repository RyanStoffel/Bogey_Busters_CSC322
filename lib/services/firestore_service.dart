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

  // ==================== Course Caching Methods ====================

  static const Duration _cacheDuration = Duration(days: 90);

  /// Sanitize course ID to be used as Firestore document ID
  /// Firestore document IDs cannot contain forward slashes
  String _sanitizeCourseId(String courseId) {
    return courseId.replaceAll('/', '_');
  }

  /// Get cached course details if available and not expired
  /// Returns null if not cached or expired (older than 90 days)
  Future<Course?> getCachedCourse(String courseId) async {
    print('ENTERING getCachedCourse for: $courseId');
    try {
      final sanitizedId = _sanitizeCourseId(courseId);
      print('Attempting Firestore query for: $courseId (sanitized: $sanitizedId)');
      final doc = await _db.collection('courses').doc(sanitizedId).get();
      print('Firestore query completed for: $courseId');

      if (!doc.exists) {
        print('No cache found for course: $courseId');
        return null;
      }

      final data = doc.data();
      if (data == null) {
        print('Cache data is null for course: $courseId');
        return null;
      }

      final cachedAt = (data['cachedAt'] as Timestamp?)?.toDate();
      if (cachedAt == null) {
        print('Cache timestamp missing for course: $courseId');
        return null;
      }

      final now = DateTime.now();

      // Check if cache is expired (older than 90 days)
      if (now.difference(cachedAt) > _cacheDuration) {
        print('Cache expired for course: $courseId (cached ${now.difference(cachedAt).inDays} days ago)');
        // Don't delete expired cache - just return null to trigger re-fetch
        // The re-fetch will update the cache with new timestamp
        return null;
      }

      print('Cache hit for course: $courseId (cached ${now.difference(cachedAt).inDays} days ago)');

      final courseData = data['courseData'];
      if (courseData == null) {
        print('Course data is null for: $courseId');
        return null;
      }

      // Ensure courseData is properly cast to Map<String, dynamic>
      final Map<String, dynamic> courseMap = Map<String, dynamic>.from(courseData as Map);
      return Course.fromJson(courseMap);
    } catch (e, stackTrace) {
      print('Error getting cached course $courseId: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Cache course details to Firestore with timestamp
  Future<void> cacheCourse(Course course) async {
    try {
      final courseJson = course.toJson();
      final sanitizedId = _sanitizeCourseId(course.courseId);

      await _db.collection('courses').doc(sanitizedId).set({
        'courseId': course.courseId,
        'courseData': courseJson,
        'cachedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Merge to avoid overwriting existing fields
      print('Successfully cached course: ${course.courseName} (${course.courseId})');
    } catch (e, stackTrace) {
      print('Error caching course ${course.courseId}: $e');
      print('Stack trace: $stackTrace');
      // Don't throw - caching failure shouldn't break the app
    }
  }

  /// Clear cache for a specific course
  Future<void> clearCourseCache(String courseId) async {
    try {
      final sanitizedId = _sanitizeCourseId(courseId);
      // Update the document to remove cached data and timestamp
      await _db.collection('courses').doc(sanitizedId).update({
        'courseData': FieldValue.delete(),
        'cachedAt': FieldValue.delete(),
      });
      print('Cleared cache for course: $courseId');
    } catch (e) {
      print('Error clearing cache for course $courseId: $e');
    }
  }

  /// Clear all cached courses (for manual refresh)
  Future<void> clearAllCourseCache() async {
    try {
      final snapshot = await _db.collection('courses').get();
      final batch = _db.batch();

      for (var doc in snapshot.docs) {
        // Remove courseData and cachedAt fields but keep courseId
        batch.update(doc.reference, {
          'courseData': FieldValue.delete(),
          'cachedAt': FieldValue.delete(),
        });
      }

      await batch.commit();
      print('Cleared all course cache (${snapshot.docs.length} courses)');
    } catch (e) {
      print('Error clearing all course cache: $e');
    }
  }
}
