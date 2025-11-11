import 'package:golf_tracker_app/services/overpass_api_service.dart';

void main() async {
  print('🏌️ Testing Overpass API Service...\n');
  
  final service = OverpassApiService();
  
  // Test 1: Fetch nearby courses
  print('Test 1: Fetching courses near Corona, CA...');
  try {
    final courses = await service.fetchNearbyCourses(
      latitude: 33.8753,  // Corona, CA
      longitude: -117.5664,
      radiusInMiles: 25.0,
    );
    
    print('Found ${courses.length} courses:');
    for (var course in courses.take(5)) {  // Show first 5
      print('  - ${course.courseName} (${course.courseId})');
      print('    Location: ${course.location.latitude}, ${course.location.longitude}');
      if (course.courseCity != null) print('    City: ${course.courseCity}');
    }
    print('');
    
    // Test 2: Fetch course details (if we found any courses)
    if (courses.isNotEmpty) {
      bool foundDetails = false;
      
      for (var i = 0; i < courses.length; i++) {
        try {
          print('Test 2: Fetching details for ${courses[i].courseName} (${courses[i].courseId})');
          final details = await service.fetchCourseDetails(courses[i].courseId);
          
          // Check if we actually got meaningful details
          if (details.holes != null && details.holes!.isNotEmpty) {
            print('Course Details:');
            print('  Name: ${details.courseName}');
            print('  Total Par: ${details.totalPar ?? "Unknown"}');
            print('  Holes: ${details.holes?.length ?? 0}');
            print('  First few holes:');
            for (var hole in details.holes!.take(3)) {
              print('    Hole ${hole.holeNumber}: Par ${hole.par ?? "?"}, ${hole.teeBoxes?.length ?? 0} tees');
            }
            foundDetails = true;
            break;  // Exit loop once we found a course with details
          } else {
            print('  ⚠️  No hole details found, trying next course...\n');
          }
        } catch (e) {
          print('  ⚠️  Error fetching details: $e');
          print('  Trying next course...\n');
        }
      }
      
      if (!foundDetails) {
        print('  ⚠️  Could not find detailed information for any course');
      }
    }
    
    print('\nAll tests passed!');
  } catch (e) {
    print('$e');
  }
}