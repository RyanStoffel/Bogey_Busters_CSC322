import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/models/models.dart';
import 'package:golf_tracker_app/services/course_service.dart';
import 'package:golf_tracker_app/services/firestore_service.dart';
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
  final CourseService _courseService = CourseService();
  final FirestoreService _firestoreService = FirestoreService();
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
      // Load cached courses only (no API calls unless refresh is pressed)
      _courses = _loadCourses(fetchFromApi: false);
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

  Future<List<Course>> _loadCourses({bool fetchFromApi = false}) async {
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

      final courseIds = await _courseService.getCourseIds();

      print('Found ${courseIds.length} course IDs in Firebase');

      print(
          'Fetching detailed information for ${courseIds.length} courses (checking cache first)...');

      final detailFutures = courseIds.map((courseId) async {
        try {
          print('Starting to process course: $courseId');

          // First, try to get from Firestore cache
          Course? cachedCourse;
          try {
            print('Checking cache for: $courseId');
            cachedCourse = await _firestoreService.getCachedCourse(courseId);
            print('Cache check complete for: $courseId');

            if (cachedCourse != null) {
              print('Using cached data for ${cachedCourse.courseName}');
              return cachedCourse;
            } else {
              print('No cached data found for: $courseId');
            }
          } catch (cacheError) {
            print('Cache retrieval error for $courseId: $cacheError');
          }

          // Only fetch from API if explicitly requested (via refresh button)
          if (!fetchFromApi) {
            print('Skipping API fetch for $courseId (fetchFromApi=false)');
            return null;
          }

          // If not cached and API fetch is allowed, fetch from Overpass API
          print('Loading details from API for $courseId');
          final course = await _overpassApiService.fetchCourseDetails(courseId);
          print('Successfully loaded ${course.courseName}');

          // Cache the course in Firestore for future use (don't await to avoid blocking)
          _firestoreService.cacheCourse(course).catchError((e) {
            print('Failed to cache course ${course.courseName}: $e');
          });

          return course;
        } catch (e) {
          print('Failed to fetch details for $courseId: $e');
          // Try to get basic info from the course ID
          try {
            final basicCourse = await _courseService.getCourseBasicInfo(courseId);
            if (basicCourse != null) {
              print(' Loaded basic info for ${basicCourse.courseName}');
              return basicCourse;
            }
          } catch (e2) {
            print(' Failed to get basic info: $e2');
          }
          return null;
        }
      }).toList();

      // Wait for all course details to be fetched at once
      final results = await Future.wait(detailFutures);
      final detailedCourses = results
          .where((course) => course != null)
          .cast<Course>()
          .toList();

      print('Successfully loaded ${detailedCourses.length}/${courseIds.length} courses with full details');
      detailedCourses.sort((a, b) {
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

  void _showSuggestCourseDialog() {
    final courseNameController = TextEditingController();
    final courseIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Suggest a Golf Course'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Help us expand our course library! Provide either a course name or OpenStreetMap ID.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: courseNameController,
                  cursorColor: Colors.green,
                  decoration: InputDecoration(
                    labelText: 'Course Name (Optional)',
                    floatingLabelStyle: TextStyle(color: Colors.green),
                    hintText: 'e.g., Pebble Beach Golf Links',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.golf_course),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: courseIdController,
                  cursorColor: Colors.green,
                  decoration: InputDecoration(
                    labelText: 'OpenStreetMap ID (Optional)',
                    floatingLabelStyle: TextStyle(color: Colors.green),
                    hintText: 'e.g., relation/12345',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.map),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final courseName = courseNameController.text.trim();
                final courseId = courseIdController.text.trim();

                if (courseName.isEmpty && courseId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter either a course name or OpenStreetMap ID'),
                    ),
                  );
                  return;
                }

                // Validate course ID format if provided
                if (courseId.isNotEmpty && !RegExp(r'^(relation|way|node)/\d+$').hasMatch(courseId)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid format. Use: relation/12345 or way/67890'),
                    ),
                  );
                  return;
                }

                try {
                  // Submit to courses_under_review collection
                  await FirebaseFirestore.instance.collection('courses_under_review').add({
                    'courseName': courseName.isNotEmpty ? courseName : null,
                    'courseId': courseId.isNotEmpty ? courseId : null,
                    'suggestedBy': FirebaseAuth.instance.currentUser?.uid,
                    'suggestedByEmail': FirebaseAuth.instance.currentUser?.email,
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'pending',
                  });

                  Navigator.of(dialogContext).pop();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Course suggestion submitted! We\'ll review it soon.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error submitting suggestion: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt),
            tooltip: 'Suggest Course',
            onPressed: _showSuggestCourseDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Clearing cache and refreshing courses...'),
                  duration: Duration(seconds: 2),
                ),
              );

              // Clear Firestore cache
              await _firestoreService.clearAllCourseCache();

              setState(() {
                _displayCount = 15;
                // Clear in-memory cache and force refresh with API calls
                _cachedCourses = null;
                _lastFetchTime = null;
                _courses = _loadCourses(fetchFromApi: true);
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
              cursorColor: Colors.green,
              
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search courses...',
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.green),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green.withOpacity(0.5)),
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
                      course: course,
                      courseLatitude: course.location.latitude,
                      courseLongitude: course.location.longitude,
                      onPreview: () {
                        if (!context.mounted) return;
                        context.push('/courses/preview', extra: course);
                      },
                      onPlay: () {
                        if (!context.mounted) return;
                        context.push('/course-details',
                            extra: course);
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
