import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Fetch all courses from Firestore for display purposes
  Future<List<Map<String, dynamic>>> getAllCoursesForDisplay() async {
    try {
      final snapshot = await _firestore.collection('courses').get();

      List<Map<String, dynamic>> courses = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Get the download URL for the image if it's a storage path
        String? imageUrl = data['imageUrl'];
        if (imageUrl != null && imageUrl.startsWith('gs://')) {
          imageUrl = await _getDownloadUrl(imageUrl);
        }

        // Handle holes field - it could be an int (total holes) or a List (hole objects)
        int totalHoles = 18; // default
        if (data['holes'] != null) {
          if (data['holes'] is int) {
            totalHoles = data['holes'] as int;
          } else if (data['holes'] is List) {
            totalHoles = (data['holes'] as List).length;
          }
        } else if (data['totalHoles'] != null) {
          totalHoles = data['totalHoles'] as int;
        }

        courses.add({
          'id': doc.id,
          'name': data['courseName'] ?? data['name'] ?? 'Unknown Course',
          'holes': totalHoles,
          'holesData': data['holes'], // Pass the raw holes data from Firebase
          'par': data['totalPar'] ?? data['par'] ?? 72,
          'distance': data['distance'] ?? 'Unknown distance',
          'totalYards':
              data['totalYards']?.toString() ?? data['distance'] ?? 'Unknown distance',
          'hasCarts': data['hasCarts'] ?? false,
          'imageUrl': imageUrl ?? '',
          'latitude': data['latitude'] as double?,
          'longitude': data['longitude'] as double?,
        });
      }

      return courses;
    } catch (e) {
      print('Error fetching courses: $e');
      return [];
    }
  }

  /// Stream of courses for real-time updates
  Stream<List<Map<String, dynamic>>> getCoursesStream() {
    return _firestore.collection('courses').snapshots().asyncMap((snapshot) async {
      List<Map<String, dynamic>> courses = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        String? imageUrl = data['imageUrl'];
        if (imageUrl != null && imageUrl.startsWith('gs://')) {
          imageUrl = await _getDownloadUrl(imageUrl);
        }

        // Handle holes field - it could be an int (total holes) or a List (hole objects)
        int totalHoles = 18; // default
        if (data['holes'] != null) {
          if (data['holes'] is int) {
            totalHoles = data['holes'] as int;
          } else if (data['holes'] is List) {
            totalHoles = (data['holes'] as List).length;
          }
        } else if (data['totalHoles'] != null) {
          totalHoles = data['totalHoles'] as int;
        }

        courses.add({
          'id': doc.id,
          'name': data['courseName'] ?? data['name'] ?? 'Unknown Course',
          'holes': totalHoles,
          'holesData': data['holes'], // Pass the raw holes data from Firebase
          'par': data['totalPar'] ?? data['par'] ?? 72,
          'distance': data['distance'] ?? 'Unknown distance',
          'totalYards':
              data['totalYards']?.toString() ?? data['distance'] ?? 'Unknown distance',
          'hasCarts': data['hasCarts'] ?? false,
          'imageUrl': imageUrl ?? '',
          'latitude': data['latitude'] as double?,
          'longitude': data['longitude'] as double?,
        });
      }

      return courses;
    });
  }

  /// Convert Firebase Storage path (gs://) to download URL
  Future<String> _getDownloadUrl(String gsUrl) async {
    try {
      // Remove 'gs://' and bucket name to get the path
      final path = gsUrl.replaceFirst(RegExp(r'gs://[^/]+/'), '');
      final ref = _storage.ref(path);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error getting download URL: $e');
      return '';
    }
  }
}
