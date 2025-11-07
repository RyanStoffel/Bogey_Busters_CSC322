import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/services/course_service.dart';
import 'package:golf_tracker_app/widgets/course_cards.dart';

class CoursesScreen extends StatelessWidget {
  final CourseService _service = CourseService();

  CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Courses')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _service.getAllCoursesForDisplay(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading courses: ${snapshot.error}'));
          }
          final courses = snapshot.data ?? [];
          if (courses.isEmpty) {
            return const Center(child: Text('No courses found'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return CourseCard(
                type: CourseCardType.courseCard,
                courseName: course['name'] ?? 'Unknown',
                courseImage: 'assets/images/default.png',
                imageUrl: (course['imageUrl'] as String?)?.isNotEmpty == true
                    ? course['imageUrl'] as String
                    : null,
                holes: course['holes'] as int? ?? 18,
                par: course['par'] as int? ?? 72,
                distance: course['totalYards'] as String? ?? 'Unknown distance',
                hasCarts: course['hasCarts'] as bool? ?? false,
                courseLatitude: course['latitude'] as double?,
                courseLongitude: course['longitude'] as double?,
                onPreview: () {
                  context.push('/courses/course-preview', extra: course);
                },
                onPlay: () {},
              );
            },
          );
        },
      ),
    );
  }
}
