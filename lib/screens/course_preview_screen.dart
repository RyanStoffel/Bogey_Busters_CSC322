import 'package:flutter/material.dart';
import 'package:golf_tracker_app/models/models.dart';
import 'package:golf_tracker_app/utils/image_helper.dart';
import 'package:go_router/go_router.dart';

class CoursePreviewScreen extends StatefulWidget {
  final Course course;

  const CoursePreviewScreen({super.key, required this.course});

  @override
  State<CoursePreviewScreen> createState() => _CoursePreviewScreenState();
}

class _CoursePreviewScreenState extends State<CoursePreviewScreen> {
  @override
  Widget build(BuildContext context) {
    final course = widget.course;

    return Scaffold(
      appBar: AppBar(
        title: Text(course.courseName),
        backgroundColor: const Color(0xFF6B8E4E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Placeholder image since Overpass doesn't provide images
            Container(
              width: double.infinity,
              height: 250,
              color: Colors.grey[300],
              child: Image.asset(
                getRandomCourseImage(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Icon(Icons.golf_course, size: 50, color: Colors.grey[600]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.courseName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3E1F),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        'Holes',
                        course.holes?.length.toString() ?? 'N/A',
                      ),
                      _buildStatColumn(
                        'Par',
                        course.totalPar?.toString() ?? 'N/A',
                      ),
                      _buildStatColumn(
                        'Yards',
                        _calculateTotalYards(course).toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Contact Information
                  if (course.phoneNumber != null)
                    _buildInfoRow('Phone', course.phoneNumber!),
                  if (course.website != null)
                    _buildInfoRow('Website', course.website!),
                  
                  // Address Information
                  if (_buildAddress(course).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow('Address', _buildAddress(course)),
                  ],
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        context.push('/course-details', extra: course);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B8E4E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Start Round',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Hole Details Table
                  if (course.holes != null && course.holes!.isNotEmpty) ...[
                    const Text(
                      'Hole Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3E1F),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildHolesTable(course),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHolesTable(Course course) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF6B8E4E).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF6B8E4E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Hole',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Par',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Yards',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'HCP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...(course.holes!.asMap().entries.map((entry) {
            final index = entry.key;
            final hole = entry.value;
            final isEven = index % 2 == 0;

            // Get white tee yardage
            int? yards;
            if (hole.teeBoxes != null && hole.teeBoxes!.isNotEmpty) {
              final whiteTee = hole.teeBoxes!.firstWhere(
                (tee) => tee.tee.toLowerCase() == 'white',
                orElse: () => hole.teeBoxes!.first,
              );
              yards = whiteTee.yards;
            }

            return Container(
              decoration: BoxDecoration(
                color: isEven
                    ? const Color(0xFFE8F1D4).withOpacity(0.3)
                    : Colors.white,
                borderRadius: index == course.holes!.length - 1
                    ? const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      )
                    : null,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Hole ${hole.holeNumber}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D3E1F),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      hole.par?.toString() ?? 'N/A',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B8E4E),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      yards.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B8E4E),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      hole.handicap?.toString() ?? 'N/A',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2D3E1F),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList()),
        ],
      ),
    );
  }

  String _buildAddress(Course course) {
    final parts = <String>[];
    
    if (course.courseHouseNumber != null && course.courseStreetAddress != null) {
      parts.add('${course.courseHouseNumber} ${course.courseStreetAddress}');
    } else if (course.courseStreetAddress != null) {
      parts.add(course.courseStreetAddress!);
    }
    
    if (course.courseCity != null) {
      parts.add(course.courseCity!);
    }
    
    if (course.courseState != null) {
      parts.add(course.courseState!);
    }
    
    if (course.coursePostalCode != null) {
      parts.add(course.coursePostalCode!);
    }
    
    return parts.join(', ');
  }

  int _calculateTotalYards(Course course) {
    if (course.holes == null || course.holes!.isEmpty) {
      return 0;
    }

    int totalYards = 0;
    
    for (var hole in course.holes!) {
      if (hole.teeBoxes != null && hole.teeBoxes!.isNotEmpty) {
        final whiteTee = hole.teeBoxes!.firstWhere(
          (tee) => tee.tee.toLowerCase() == 'white',
          orElse: () => hole.teeBoxes!.first,
        );
        
        if (whiteTee.yards != null) {
          totalYards += whiteTee.yards!;
        }
      }
    }
    
    return totalYards;
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B8E4E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3E1F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}