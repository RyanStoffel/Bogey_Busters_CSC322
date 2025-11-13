import 'package:flutter/material.dart';
import 'package:golf_tracker_app/services/overpass_api_service.dart';
import 'package:golf_tracker_app/models/models.dart';
import 'package:golf_tracker_app/widgets/course_cards.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final OverpassApiService _overpassApiService = OverpassApiService();
  late Future<List<Course>> _courses;
  int _displayCount = 5; // Number of courses to display initially

  @override
  void initState() {
    super.initState();
    _courses = _loadCourses();
  }

  void _loadMoreCourses() {
    setState(() {
      _displayCount += 10;
    });
  }

  Future<List<Course>> _loadCourses() async {
    try {
      // Hardcoded CBU location as fallback
      const double cbuLatitude = 33.929483;
      const double cbuLongitude = -117.286400;
      
      double latitude = cbuLatitude;
      double longitude = cbuLongitude;

      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission != LocationPermission.deniedForever && 
            permission != LocationPermission.denied) {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          latitude = position.latitude;
          longitude = position.longitude;
        }
      } catch (e) {
        print('Error getting location: $e');
      }

      List<Course> courses = await _overpassApiService.fetchNearbyCourses(
        latitude: latitude,
        longitude: longitude,
        radiusInMiles: 25.0,
      );

      // Sort courses by distance from current location (closest first)
      courses.sort((a, b) {
        double distanceA = Geolocator.distanceBetween(
          latitude,
          longitude,
          a.location.latitude!,
          a.location.longitude!,
        );
        double distanceB = Geolocator.distanceBetween(
          latitude,
          longitude,
          b.location.latitude!,
          b.location.longitude!,
        );
        return distanceA.compareTo(distanceB);
      });

      return courses;
    } catch (e) {
      throw Exception('Failed to load courses: $e');
    }
  }

  String _formatAddress(Course course) {
    final parts = <String>[];
    
    if (course.courseHouseNumber != null) parts.add(course.courseHouseNumber!);
    if (course.courseStreetAddress != null) parts.add(course.courseStreetAddress!);
    if (course.courseCity != null) parts.add(course.courseCity!);
    if (course.courseState != null) parts.add(course.courseState!);
    
    return parts.isEmpty ? 'Address not available' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _displayCount = 15; // Reset display count
                _courses = _loadCourses();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Course>>(
        future: _courses,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green,),
                  SizedBox(height: 16),
                  Text('Loading nearby courses...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading courses',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _courses = _loadCourses();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final courses = snapshot.data ?? [];
          
          if (courses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.golf_course, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No courses found nearby',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Try adjusting your search radius'),
                ],
              ),
            );
          }

          // Limit the displayed courses to _displayCount
          final displayedCourses = courses.take(_displayCount).toList();
          final hasMore = courses.length > _displayCount;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: displayedCourses.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Show "Load More" button as the last item if there are more courses
              if (index == displayedCourses.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: _loadMoreCourses,
                      icon: const Icon(Icons.arrow_downward),
                      label: Text('Load More (${courses.length - _displayCount} remaining)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        foregroundColor: Colors.green,
                      ),
                    ),
                  ),
                );
              }

              final course = displayedCourses[index];
              
              return CourseCard(
                type: CourseCardType.courseCard,
                courseName: course.courseName,
                courseImage: 'assets/images/default.png',
                imageUrl: null, 
                holes: 18, 
                par: course.totalPar ?? 72, 
                distance: _formatAddress(course),
                hasCarts: false, 
                courseLatitude: course.location.latitude,
                courseLongitude: course.location.longitude,
                onPreview: () {
                  // Navigate to course preview screen with courseId
                  context.push('/courses/preview/${Uri.encodeComponent(course.courseId)}');
                },
                onPlay: () {
                  // TODO: Implement start round functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Starting round at ${course.courseName}'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}