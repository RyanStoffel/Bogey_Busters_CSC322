import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/models/models.dart';

class CourseDetailsSelectionScreen extends StatefulWidget {
  final Course course;

  const CourseDetailsSelectionScreen({
    super.key,
    required this.course,
  });

  @override
  State<CourseDetailsSelectionScreen> createState() =>
      _CourseDetailsSelectionScreenState();
}

class _CourseDetailsSelectionScreenState extends State<CourseDetailsSelectionScreen> {
  String? selectedTeeColor;
  List<String> availableTees = [];
  Map<String, List<String>> _teeBoxMapping = {}; // Display color -> actual API tee names

  @override
  void initState() {
    super.initState();
    _extractAvailableTees();
  }

  void _extractAvailableTees() {
    final Map<String, List<String>> teeBoxMapping = {}; // Color -> actual API tee names
    final Set<String> individualTees = {};
    final Set<String> sharedTees = {};

    // Categorize tees across all holes
    if (widget.course.holes != null) {
      for (var hole in widget.course.holes!) {
        if (hole.teeBoxes != null) {
          for (var teeBox in hole.teeBoxes!) {
            if (teeBox.tee.contains(';')) {
              sharedTees.add(teeBox.tee);
            } else {
              individualTees.add(teeBox.tee);
            }
          }
        }
      }
    }

    // Determine course type and build display tees
    Set<String> displayTees = {};

    if (individualTees.isNotEmpty) {
      // Type 1 or 2: Has some individual tees (most full courses, or mixed)
      // Use only individual tees, ignore shared ones to avoid duplicates
      displayTees = individualTees;

      // Build mapping for individual tees
      for (var tee in individualTees) {
        final capitalizedTee = _capitalizeTee(tee);
        teeBoxMapping[capitalizedTee] = [tee]; // Maps "BLUE" -> ["blue"]
        displayTees = displayTees.map((t) => _capitalizeTee(t)).toSet();
      }
    } else if (sharedTees.isNotEmpty) {
      // Type 3: Only shared tees (par 3 courses)
      // Split shared tees into individual options
      for (var shared in sharedTees) {
        var colors = shared.split(';');
        for (var color in colors) {
          var trimmedColor = color.trim();
          var capitalizedColor = _capitalizeTee(trimmedColor);
          displayTees.add(capitalizedColor);
          teeBoxMapping.putIfAbsent(capitalizedColor, () => []);
          if (!teeBoxMapping[capitalizedColor]!.contains(shared)) {
            teeBoxMapping[capitalizedColor]!.add(shared);
          }
        }
      }
    }

    // If no tees found from holes, provide default options
    if (displayTees.isEmpty) {
      displayTees.addAll(['Black', 'Blue', 'White', 'Gold', 'Red']);
      for (var tee in displayTees) {
        teeBoxMapping[tee] = [tee];
      }
    }

    // Store mapping for later use
    _teeBoxMapping = teeBoxMapping;

    setState(() {
      availableTees = displayTees.toList();
      // Sort tees in traditional order
      availableTees.sort((a, b) {
        const order = ['Black', 'Blue', 'White', 'Gold', 'Red'];
        int aIndex = order.indexOf(a);
        int bIndex = order.indexOf(b);
        if (aIndex == -1) aIndex = 999;
        if (bIndex == -1) bIndex = 999;
        return aIndex.compareTo(bIndex);
      });

      // Default to White tees if available
      if (availableTees.contains('White')) {
        selectedTeeColor = 'White';
      } else if (availableTees.isNotEmpty) {
        selectedTeeColor = availableTees.first;
      }
    });
  }

  String _capitalizeTee(String tee) {
    if (tee.isEmpty) return tee;
    return tee[0].toUpperCase() + tee.substring(1).toLowerCase();
  }

  Color _getTeeColor(String tee) {
    switch (tee.toLowerCase()) {
      case 'black':
        return Colors.black;
      case 'blue':
        return Colors.blue;
      case 'white':
        return Colors.white;
      case 'gold':
        return Colors.amber;
      case 'yellow':
        return Colors.yellow;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _startRound() {
    if (selectedTeeColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a tee box'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    context.push('/in-round', extra: {
      'course': widget.course,
      'teeColor': selectedTeeColor,
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalHoles = widget.course.holes?.length ?? 18;
    final totalPar = widget.course.totalPar ?? 72;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.courseName),
        backgroundColor: const Color(0xFF6B8E4E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1D4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.course.courseName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3E1F),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('Holes', totalHoles.toString()),
                        _buildStatColumn('Par', totalPar.toString()),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Tee Selection
              const Text(
                'Select Tee Box',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3E1F),
                ),
              ),
              const SizedBox(height: 16),

              if (availableTees.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No tee information available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...availableTees.map((tee) => _buildTeeOption(tee)),

              const SizedBox(height: 32),

              // Start Round Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: selectedTeeColor != null ? _startRound : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B8E4E),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Start Round',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B8E4E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildTeeOption(String tee) {
    final isSelected = selectedTeeColor == tee;
    final teeColor = _getTeeColor(tee);
    final isDark = tee.toLowerCase() == 'black' || tee.toLowerCase() == 'blue';

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTeeColor = tee;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6B8E4E).withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF6B8E4E) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: teeColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.grey : Colors.grey[800]!,
                  width: tee.toLowerCase() == 'white' ? 2 : 0,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '$tee Tees',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: const Color(0xFF2D3E1F),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF6B8E4E),
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
