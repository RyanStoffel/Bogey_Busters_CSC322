import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:golf_tracker_app/models/models.dart';

class CourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Fetch course IDs from Firebase courses collection
  Future<List<String>> getCourseIds() async {
    try {
      final snapshot = await _firestore.collection('courses').get();
      return snapshot.docs
          .map((doc) => doc.data()['courseId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();
    } catch (e) {
      print('Error fetching course IDs from Firebase: $e');
      return [];
    }
  }

  /// Get basic course info from Firebase when Overpass API fails
  Future<Course?> getCourseBasicInfo(String courseId) async {
    try {
      final snapshot = await _firestore
          .collection('courses')
          .where('courseId', isEqualTo: courseId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final data = snapshot.docs.first.data();
      
      // Extract latitude and longitude
      double? lat;
      double? lon;
      if (data['location'] != null && data['location'] is Map) {
        lat = (data['location']['latitude'] as num?)?.toDouble();
        lon = (data['location']['longitude'] as num?)?.toDouble();
      }

      if (lat == null || lon == null) {
        return null;
      }

      return Course(
        courseId: courseId,
        courseName: data['courseName'] ?? data['name'] ?? 'Unknown Course',
        location: CoordinatePoint(latitude: lat, longitude: lon),
        totalPar: data['totalPar'] as int? ?? data['par'] as int?,
        courseStreetAddress: data['courseStreetAddress'] as String?,
        courseHouseNumber: data['courseHouseNumber'] as String?,
        courseCity: data['courseCity'] as String?,
        courseState: data['courseState'] as String?,
        coursePostalCode: data['coursePostalCode'] as String?,
        phoneNumber: data['phoneNumber'] as String?,
        website: data['website'] as String?,
      );
    } catch (e) {
      print('Error fetching basic course info from Firebase: $e');
      return null;
    }
  }

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

        // Extract latitude and longitude from location object or direct fields
        double? latitude;
        double? longitude;
        if (data['location'] != null && data['location'] is Map) {
          latitude = data['location']['latitude'] as double?;
          longitude = data['location']['longitude'] as double?;
        } else {
          latitude = data['latitude'] as double?;
          longitude = data['longitude'] as double?;
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
          'imageUrl': imageUrl ?? '',
          'latitude': latitude,
          'longitude': longitude,
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

        // Extract latitude and longitude from location object or direct fields
        double? latitude;
        double? longitude;
        if (data['location'] != null && data['location'] is Map) {
          latitude = data['location']['latitude'] as double?;
          longitude = data['location']['longitude'] as double?;
        } else {
          latitude = data['latitude'] as double?;
          longitude = data['longitude'] as double?;
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
          'imageUrl': imageUrl ?? '',
          'latitude': latitude,
          'longitude': longitude,
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
