import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/services/services.dart';
import 'package:golf_tracker_app/utils/image_helper.dart';
import 'package:golf_tracker_app/widgets/course_cards.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _courseIdController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isAdmin = false;
  bool _isAddingCourse = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _courseIdController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final isAdmin = await _firestoreService.isUserAdmin(user.uid);
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  Future<void> _addCourseId() async {
    final courseId = _courseIdController.text.trim();

    // Validate course ID format
    if (courseId.isEmpty) {
      _showMessage('Please enter a course ID');
      return;
    }

    if (!RegExp(r'^(relation|way|node)/\d+$').hasMatch(courseId)) {
      _showMessage('Invalid format. Use: relation/12345 or way/67890');
      return;
    }

    setState(() {
      _isAddingCourse = true;
    });

    try {
      // Add course ID to Firestore
      await FirebaseFirestore.instance.collection('courses').add({
        'courseId': courseId,
      });

      _showMessage('Course ID added successfully!');
      _courseIdController.clear();
    } catch (e) {
      _showMessage('Error adding course: $e');
    } finally {
      setState(() {
        _isAddingCourse = false;
      });
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'About Bogey Busters',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mission Statement
                        _buildSection(
                          icon: Icons.flag,
                          title: 'Our Mission',
                          content:
                              'Built by golfers, for golfers. We created Bogey Busters because we love golf, but hated paying expensive subscription fees for tracking apps. This is our passion project; building an app we truly love using, and sharing it with the community for free.',
                        ),
                        const SizedBox(height: 24),

                        // Meet the Founders
                        _buildSection(
                          icon: Icons.people,
                          title: 'Meet the Founders',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFounderCard(
                                name: 'Ryan Stoffel',
                                role: 'Co-Founder & Developer',
                                bio: 'Passionate about golf and technology. Building tools that make the game more accessible and enjoyable for everyone.',
                              ),
                              const SizedBox(height: 12),
                              _buildFounderCard(
                                name: 'Payton Henry',
                                role: 'Co-Founder & Developer',
                                bio: 'Golf enthusiast and app developer. Dedicated to creating a free, powerful alternative to expensive golf tracking apps.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Open Source
                        _buildSection(
                          icon: Icons.code,
                          title: 'Open Source Project',
                          content:
                              'This app is 100% open source. We believe in transparency and community-driven development. View the code, contribute features, or report bugs on GitHub.',
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('View on GitHub'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black87,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // OpenStreetMap Credits
                        _buildSection(
                          icon: Icons.map,
                          title: 'Powered by OpenStreetMap',
                          content:
                              'Course data provided by OpenStreetMap contributors. We\'re grateful to the OSM community for making detailed golf course maps freely available to everyone.',
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextButton.icon(
                              onPressed: () {
                                // TODO: Open OpenStreetMap
                              },
                              icon: const Icon(Icons.public),
                              label: const Text('Visit OpenStreetMap'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Get Involved
                        _buildSection(
                          icon: Icons.volunteer_activism,
                          title: 'Get Involved',
                          content:
                              'Help us make golf tracking better for everyone! Suggest features, report bugs, or contribute code.',
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    // TODO: Contact email
                                  },
                                  icon: const Icon(Icons.email),
                                  label: const Text('Contact Us'),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    // TODO: GitHub issues
                                  },
                                  icon: const Icon(Icons.bug_report),
                                  label: const Text('Report an Issue'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    String? content,
    Widget? child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (content != null)
          Text(
            content,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        if (child != null) child,
      ],
    );
  }

  Widget _buildFounderCard({
    required String name,
    required String role,
    required String bio,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            role,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bio,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<double> _calculateHandicap(String userId) async {
    try {
      final roundsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('rounds')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final eighteenHoleRounds = roundsSnapshot.docs.where((doc) {
        final data = doc.data();
        final holes = data['holes'] ?? 0;
        return holes == 18;
      }).toList();

      if (eighteenHoleRounds.isEmpty) {
        return 0.0;
      }

      final differentials = eighteenHoleRounds.map((doc) {
        final data = doc.data();
        final score = data['score'] ?? 0;
        final par = data['par'] ?? 72;
        return (score - par).toDouble();
      }).toList();

      differentials.sort();

      final numberOfScoresToUse = differentials.length < 8 ? differentials.length : 8;
      final bestScores = differentials.take(numberOfScoresToUse).toList();

      final average = bestScores.reduce((a, b) => a + b) / bestScores.length;

      return double.parse(average.toStringAsFixed(1));
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About Bogey Busters',
            onPressed: _showAboutDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(color: Colors.green,),
                      ),
                    );
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(
                      child: Text('User data not found'),
                    );
                  }

                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  final firstName = userData['firstName'] ?? '';
                  final lastName = userData['lastName'] ?? '';
                  final fullName = '$firstName $lastName'.trim();
                  final bio =
                      userData['bio'] ?? 'Add a bio to tell others about yourself...';

                  return FutureBuilder<double>(
                    future: _calculateHandicap(user?.uid ?? ''),
                    builder: (context, handicapSnapshot) {
                      final handicap = handicapSnapshot.data ?? 0.0;

                      return GestureDetector(
                        onTap: () {
                          context.push('/edit-profile');
                        },
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FutureBuilder<String?>(
                                    future: FirestorageService()
                                        .getProfileImageUrl(user?.uid ?? ''),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const SizedBox(
                                          width: 80,
                                          height: 80,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.green,
                                            ),
                                          ),
                                        );
                                      }

                                      final url = snapshot.data;
                                      if (url == null || url.isEmpty) {
                                        return const CircleAvatar(
                                          radius: 40,
                                          backgroundColor: Colors.grey,
                                          child: Icon(Icons.person,
                                              size: 40, color: Colors.white),
                                        );
                                      }

                                      return CircleAvatar(
                                        radius: 40,
                                        backgroundImage: NetworkImage(url),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fullName.isEmpty ? 'No Name' : fullName,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          user?.email ?? '',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          bio,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: bio.startsWith('Add')
                                                ? Colors.grey[400]
                                                : Colors.black87,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Handicap: $handicap",
                                          style: TextStyle(
                                            fontSize: 14,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        color: Colors.grey[400],
                                        size: 20,
                                      ),
                                      const SizedBox(height: 30),
                                      GestureDetector(
                                        onTap: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                title: const Text('Logout'),
                                                content: const Text(
                                                    'Are you sure you want to logout?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context).pop(false),
                                                    child: const Text(style: TextStyle(color: Colors.black), 'Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context).pop(true),
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: Colors.red,
                                                    ),
                                                    child: const Text('Logout'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );

                                          if (confirmed == true) {
                                            await AuthService().signOut();
                                            if (context.mounted) {
                                              context.go('/login');
                                            }
                                          }
                                        },
                                        child: Icon(
                                          Icons.logout,
                                          color: Colors.red[400],
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              // Admin Section
              if (_isAdmin)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.admin_panel_settings, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Admin: Add Golf Course',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Enter OpenStreetMap course ID:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _courseIdController,
                          cursorColor: Colors.green,
                          decoration: InputDecoration(
                            focusColor: Colors.green,
                            hoverColor: Colors.green,
                            hintText: 'relation/12345 or way/67890',
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
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.golf_course),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isAddingCourse ? null : _addCourseId,
                            icon: _isAddingCourse
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add),
                            label: Text(_isAddingCourse ? 'Adding...' : 'Add Course'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Rounds History Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Round History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3E1F),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user?.uid)
                          .collection('rounds')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(color: Colors.green,),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.golf_course,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No rounds played yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final rounds = snapshot.data!.docs;

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rounds.length,
                          itemBuilder: (context, index) {
                            final roundDoc = rounds[index];
                            final roundData = roundDoc.data() as Map<String, dynamic>;
                            final scorecardId = roundDoc.id;
                            final courseName =
                                roundData['courseName'] ?? 'Unknown Course';
                            final score = roundData['score'] ?? 0;
                            final holes = roundData['holes'] ?? 18;
                            final par = roundData['par'] ?? 72;
                            final relativeToPar = score - par;

                            return CourseCard(
                              type: CourseCardType.courseScoreCard,
                              courseName: courseName,
                              courseImage: getRandomCourseImage(),
                              holes: holes,
                              par: par,
                              totalScore: score,
                              relativeToPar: relativeToPar,
                              scorecardId: scorecardId,
                              onDelete: () {
                                // StreamBuilder will automatically refresh
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
