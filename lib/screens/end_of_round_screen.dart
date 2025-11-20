import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/models/models.dart';

class EndOfRoundScreen extends StatelessWidget {
  final Course course;
  final String teeColor;
  final List<Hole> holes;
  final Map<int, int> holeScores; // holeNumber -> score

  const EndOfRoundScreen({
    super.key,
    required this.course,
    required this.teeColor,
    required this.holes,
    required this.holeScores,
  });

  int get totalScore {
    int total = 0;
    holeScores.forEach((holeNumber, score) {
      total += score;
    });
    return total;
  }

  int get totalPar {
    int total = 0;
    for (var hole in holes) {
      total += hole.par ?? 4;
    }
    return total;
  }

  int get relativeToPar {
    return totalScore - totalPar;
  }

  String get relativeToParString {
    if (relativeToPar == 0) return 'E';
    return relativeToPar > 0 ? '+$relativeToPar' : '$relativeToPar';
  }

  Color get relativeToParColor {
    if (relativeToPar > 0) return Colors.red;
    if (relativeToPar < 0) return Colors.green;
    return Colors.grey[800]!;
  }

  Future<void> _saveRound(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to save rounds'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Prepare hole data with scores
      final holesData = holes.map((hole) {
        final score = holeScores[hole.holeNumber];
        return {
          'holeNumber': hole.holeNumber,
          'par': hole.par,
          'handicap': hole.handicap,
          'score': score,
        };
      }).toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('rounds')
          .add({
        'courseName': course.courseName,
        'courseId': course.courseId,
        'teeColor': teeColor,
        'score': totalScore,
        'par': totalPar,
        'relativeToPar': relativeToPar,
        'holes': holes.length,
        'holesData': holesData,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Round saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to courses screen
      context.go('/courses');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving round: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteRound(BuildContext context) {
    // Just navigate back without saving
    context.go('/courses');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Round Complete'),
        backgroundColor: const Color(0xFF6B8E4E),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B8E4E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      course.courseName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$teeColor Tees • ${holes.length} Holes',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Score Summary
              Row(
                children: [
                  Expanded(
                    child: _buildScoreCard(
                      'Total Score',
                      totalScore.toString(),
                      const Color(0xFF6B8E4E),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildScoreCard(
                      'To Par',
                      relativeToParString,
                      relativeToParColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Par Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Par', totalPar.toString()),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.grey[300],
                    ),
                    _buildStatItem('Holes', holes.length.toString()),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Hole-by-Hole Breakdown
              const Text(
                'Hole-by-Hole',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Front 9
              if (holes.length >= 9) ...[
                _buildHoleSection('Front 9', 1, 9),
                const SizedBox(height: 16),
              ],

              // Back 9
              if (holes.length >= 18) ...[
                _buildHoleSection('Back 9', 10, 18),
                const SizedBox(height: 16),
              ],

              // All holes if not 18
              if (holes.length < 9 || (holes.length > 9 && holes.length < 18))
                _buildHoleSection('All Holes', 1, holes.length),

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _deleteRound(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.red[400]!, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Delete Round',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[400],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _saveRound(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B8E4E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Round',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildHoleSection(String title, int startHole, int endHole) {
    final sectionHoles = holes
        .where((h) => h.holeNumber >= startHole && h.holeNumber <= endHole)
        .toList()
      ..sort((a, b) => a.holeNumber.compareTo(b.holeNumber));

    int sectionScore = 0;
    int sectionPar = 0;
    for (var hole in sectionHoles) {
      sectionScore += holeScores[hole.holeNumber] ?? 0;
      sectionPar += hole.par ?? 4;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$sectionScore ($sectionPar)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: sectionScore > sectionPar
                    ? Colors.red
                    : sectionScore < sectionPar
                        ? Colors.green
                        : Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.8,
          ),
          itemCount: sectionHoles.length,
          itemBuilder: (context, index) {
            final hole = sectionHoles[index];
            final score = holeScores[hole.holeNumber] ?? 0;
            final par = hole.par ?? 4;
            final relativeToPar = score - par;

            Color bgColor;
            Color textColor;
            if (relativeToPar > 0) {
              bgColor = Colors.red[100]!;
              textColor = Colors.red[900]!;
            } else if (relativeToPar < 0) {
              bgColor = Colors.green[100]!;
              textColor = Colors.green[900]!;
            } else {
              bgColor = Colors.grey[200]!;
              textColor = Colors.grey[900]!;
            }

            return Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${hole.holeNumber}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Par $par',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}


