import 'package:flutter/material.dart';
import 'package:golf_tracker_app/services/overpass_api_service.dart';
import 'package:golf_tracker_app/models/models.dart';

class CoursePreviewScreen extends StatefulWidget {
  final String courseId;

  const CoursePreviewScreen({super.key, required this.courseId});

  @override
  State<CoursePreviewScreen> createState() => _CoursePreviewScreenState();
}

class _CoursePreviewScreenState extends State<CoursePreviewScreen> {
  final OverpassApiService _apiService = OverpassApiService();
  Course? _course;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCourseDetails();
  }

  Future<void> _loadCourseDetails() async {
    try {
      final course = await _apiService.fetchCourseDetails(widget.courseId);
      setState(() {
        _course = course;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: const Color(0xFF6B8E4E),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6B8E4E),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: const Color(0xFF6B8E4E),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Failed to load course details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _loadCourseDetails();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B8E4E),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_course == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Course Not Found'),
          backgroundColor: const Color(0xFF6B8E4E),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Course data not available'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_course!.courseName),
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
              child: Icon(Icons.golf_course, size: 80, color: Colors.grey[600]),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _course!.courseName,
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
                        _course!.holes?.length.toString() ?? 'N/A',
                      ),
                      _buildStatColumn(
                        'Par',
                        _course!.totalPar?.toString() ?? 'N/A',
                      ),
                      _buildStatColumn(
                        'Yards',
                        _calculateTotalYards().toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Contact Information
                  if (_course!.phoneNumber != null)
                    _buildInfoRow('Phone', _course!.phoneNumber!),
                  if (_course!.website != null)
                    _buildInfoRow('Website', _course!.website!),
                  
                  // Address Information
                  if (_buildAddress().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow('Address', _buildAddress()),
                  ],
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Implement start round functionality
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
                  if (_course!.holes != null && _course!.holes!.isNotEmpty) ...[
                    const Text(
                      'Hole Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3E1F),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildHolesTable(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHolesTable() {
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
          ...(_course!.holes!.asMap().entries.map((entry) {
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
                borderRadius: index == _course!.holes!.length - 1
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

  String _buildAddress() {
    final parts = <String>[];
    
    if (_course!.courseHouseNumber != null && _course!.courseStreetAddress != null) {
      parts.add('${_course!.courseHouseNumber} ${_course!.courseStreetAddress}');
    } else if (_course!.courseStreetAddress != null) {
      parts.add(_course!.courseStreetAddress!);
    }
    
    if (_course!.courseCity != null) {
      parts.add(_course!.courseCity!);
    }
    
    if (_course!.courseState != null) {
      parts.add(_course!.courseState!);
    }
    
    if (_course!.coursePostalCode != null) {
      parts.add(_course!.coursePostalCode!);
    }
    
    return parts.join(', ');
  }

  int _calculateTotalYards() {
    if (_course?.holes == null || _course!.holes!.isEmpty) {
      return 0;
    }

    int totalYards = 0;
    
    for (var hole in _course!.holes!) {
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