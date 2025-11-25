import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/models/models.dart';
import 'package:golf_tracker_app/services/overpass_api_service.dart';
import 'package:golf_tracker_app/utils/image_helper.dart';
import 'package:golf_tracker_app/widgets/course_cards.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final OverpassApiService _overpassApiService = OverpassApiService();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Course>> _courses;
  int _displayCount = 5;
  String _searchQuery = '';

  // Cache variables
  static List<Course>? _cachedCourses;
  static DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 30); // Cache for 30 minutes

  @override
  void initState() {
    super.initState();
    // Check if we have valid cached data
    if (_cachedCourses != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      // Use cached data
      _courses = Future.value(_cachedCourses);
    } else {
      // Fetch fresh data
      _courses = _loadCourses();
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  void _loadMoreCourses() {
    setState(() {
      _displayCount += 10;
    });
  }

  List<Course> _filterCourses(List<Course> courses) {
    if (_searchQuery.isEmpty) {
      return courses;
    }

    return courses.where((course) {
      final courseName = course.courseName.toLowerCase();
      final address = _formatAddress(course).toLowerCase();
      final city = course.courseCity?.toLowerCase() ?? '';
      final state = course.courseState?.toLowerCase() ?? '';

      return courseName.contains(_searchQuery) ||
          address.contains(_searchQuery) ||
          city.contains(_searchQuery) ||
          state.contains(_searchQuery);
    }).toList();
  }

  Future<List<Course>> _loadCourses() async {
    try {
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

      // First, fetch basic course information
      List<Course> basicCourses = await _overpassApiService.fetchNearbyCourses(
        latitude: latitude,
        longitude: longitude,
        radiusInMiles: 50.0,
      );

      // Sort courses by distance
      basicCourses.sort((a, b) {
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

      // Now fetch full details for all courses IN PARALLEL (much faster!)
      print(
          'Fetching detailed information for ${basicCourses.length} courses in parallel...');

      // Create a list of futures for all course detail fetches
      final detailFutures = basicCourses.map((basicCourse) async {
        try {
          print('Loading details for ${basicCourse.courseName}');
          // Fetch complete course details including holes and tee boxes
          return await _overpassApiService.fetchCourseDetails(basicCourse.courseId);
        } catch (e) {
          // If fetching details fails for a course, keep the basic info
          print('Failed to fetch details for ${basicCourse.courseName}: $e');
          return basicCourse;
        }
      }).toList();

      // Wait for all course details to be fetched at once
      final detailedCourses = await Future.wait(detailFutures);

      print('Successfully loaded ${detailedCourses.length} courses with full details');

      // Cache the results
      _cachedCourses = detailedCourses;
      _lastFetchTime = DateTime.now();

      return detailedCourses;
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
                _displayCount = 15;
                // Clear cache and force refresh
                _cachedCourses = null;
                _lastFetchTime = null;
                _courses = _loadCourses();
                _searchController.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search courses...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          // Courses List
          Expanded(
            child: FutureBuilder<List<Course>>(
              future: _courses,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.green),
                        SizedBox(height: 16),
                        Text('Loading nearby courses...'),
                        SizedBox(height: 8),
                        Text(
                          'Fetching complete course details',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
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

                final allCourses = snapshot.data ?? [];
                final filteredCourses = _filterCourses(allCourses);

                if (filteredCourses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.golf_course, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No courses found nearby'
                              : 'No courses match your search',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Try adjusting your search radius'
                              : 'Try a different search term',
                        ),
                      ],
                    ),
                  );
                }

                final displayedCourses = filteredCourses.take(_displayCount).toList();
                final hasMore = filteredCourses.length > _displayCount;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayedCourses.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == displayedCourses.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: ElevatedButton.icon(
                            onPressed: _loadMoreCourses,
                            icon: const Icon(Icons.arrow_downward),
                            label: Text(
                                'Load More (${filteredCourses.length - _displayCount} remaining)'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
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
                      courseImage: getRandomCourseImage(),
                      imageUrl: null,
                      holes: course.holes?.length ?? 18,
                      par: course.totalPar ?? 72,
                      distance: _formatAddress(course),
                      course: course, // ADD THIS LINE - pass the full course object
                      courseLatitude: course.location.latitude,
                      courseLongitude: course.location.longitude,
                      onPreview: () {
                        if (!context.mounted) return;
                        context.push('/courses/preview', extra: course);
                      },
                      onPlay: () {
                        if (!context.mounted) return;
                        context.push('/course-details',
                            extra: course); // CHANGE THIS LINE
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
