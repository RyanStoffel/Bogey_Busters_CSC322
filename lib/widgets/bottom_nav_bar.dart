import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/services/firestorage_service.dart';
import 'package:golf_tracker_app/services/overpass_api_service.dart';
import 'package:golf_tracker_app/services/location_service.dart';
import 'package:geolocator/geolocator.dart';

class BottomNavBar extends StatefulWidget {
  final int currentIndex;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
  });

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  late Future<String?> _profileUrl;
  final LocationService _locationService = LocationService();
  final OverpassApiService _overpassApiService = OverpassApiService();

  @override
  void initState() {
    super.initState();
    _profileUrl = FirestorageService().getProfileImageUrl(FirebaseAuth.instance.currentUser?.uid ?? '');
  }

  Future<void> _navigateToClosestCourse(BuildContext context) async {
    try {
      // Get current location
      final position = await _locationService.getCurrentLocation();
      
      if (position == null) {
        return;
      }

      // Fetch nearby courses
      final courses = await _overpassApiService.fetchNearbyCourses(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusInMiles: 25.0,
      );

      if (courses.isEmpty) {
        return;
      }

      // Sort by distance and get the closest one
      courses.sort((a, b) {
        double distanceA = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          a.location.latitude!,
          a.location.longitude!,
        );
        double distanceB = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          b.location.latitude!,
          b.location.longitude!,
        );
        return distanceA.compareTo(distanceB);
      });

      final closestCourse = courses.first;
      
      // Navigate to the closest course
      if (context.mounted) {
        context.push('/courses/preview/${Uri.encodeComponent(closestCourse.courseId)}');
      }
    } catch (e) {
      print('Error finding closest course: $e');
    }
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/friends');
        break;
      case 1:
        context.go('/courses');
        break;
      case 2:
        _navigateToClosestCourse(context);
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: widget.currentIndex,
      onTap: (index) => _onTap(context, index),
      selectedItemColor: Colors.green,
      showSelectedLabels: true,
      unselectedItemColor: Colors.black,
      showUnselectedLabels: true,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.people, size: 32),
          label: "Friends",
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.sports_golf, size: 32),
          label: "Courses",
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.play_circle, size: 32),
          label: "Play",
        ),
        BottomNavigationBarItem(
          icon: FutureBuilder<String?>(
            future: _profileUrl,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.green,
                  ),
                );
              }

              final url = snapshot.data;
              if (url == null || url.isEmpty) {
                return const Icon(Icons.person, size: 32);
              }

              return CircleAvatar(
                backgroundImage: NetworkImage(url),
                radius: 16,
                backgroundColor: Colors.transparent,
              );
            },
          ),
          label: "Me",
        ),
      ],
    );
  }
}