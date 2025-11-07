import 'package:flutter/material.dart';

class CoursePreviewScreen extends StatelessWidget {
  final Map<String, dynamic> course;

  const CoursePreviewScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(course['name'] ?? 'Course Preview'),
        backgroundColor: const Color(0xFF6B8E4E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (course['imageUrl'] != null && course['imageUrl'].isNotEmpty)
              Image.network(
                course['imageUrl'],
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 250,
                    color: Colors.grey[300],
                    child: Icon(Icons.golf_course, size: 80, color: Colors.grey[600]),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course['name'] ?? 'Unknown Course',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3E1F),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Holes', '${course['holes'] ?? 'N/A'}'),
                      _buildStatColumn('Par', '${course['par'] ?? 'N/A'}'),
                      _buildStatColumn('Yards', '${course['totalYards'] ?? 'N/A'}'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                      'Carts Available', course['hasCarts'] == true ? 'Yes' : 'No'),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B8E4E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Start Round',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (course['holesData'] != null && course['holesData'] is List) ...[
                    Text(
                      'Hole Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D3E1F),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: const Color(0xFF6B8E4E).withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B8E4E),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Row(
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
                          ...((course['holesData'] as List).asMap().entries.map((entry) {
                            final index = entry.key;
                            final hole = entry.value;
                            final isEven = index % 2 == 0;

                            int whiteTeeYardsForCurrentHole = 0;

                            // Check if 'hole' is a Map and has 'teeBoxes'
                            if (hole is Map<String, dynamic> && hole['teeBoxes'] is List) {
                              // Iterate through the teeBoxes for this specific hole
                              for (var teeBoxData in hole['teeBoxes']) {
                                // Check if the teeBoxData is a Map, has a 'name', and it's 'white'
                                if (teeBoxData is Map<String, dynamic> &&
                                    teeBoxData['name'] == "white" &&
                                    teeBoxData['yards'] is int) {
                                  whiteTeeYardsForCurrentHole = teeBoxData['yards'] as int;
                                  break; // Found the 'white' tee box, no need to check others for this hole
                                }
                              }
                            }

                            return Container(
                              decoration: BoxDecoration(
                                color: isEven
                                    ? const Color(0xFFE8F1D4).withOpacity(0.3)
                                    : Colors.white,
                                borderRadius:
                                    index == (course['holesData'] as List).length - 1
                                        ? BorderRadius.only(
                                            bottomLeft: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          )
                                        : null,
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Hole ${hole['holeNumber'] ?? index + 1}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF2D3E1F),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${hole['par'] ?? 'N/A'}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6B8E4E),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      whiteTeeYardsForCurrentHole.toString(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6B8E4E),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${hole['handicap'] ?? 'N/A'}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: const Color(0xFF2D3E1F),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList()),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6B8E4E),
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
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2D3E1F),
            ),
          ),
        ],
      ),
    );
  }
}
