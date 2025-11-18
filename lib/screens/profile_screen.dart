import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/services/services.dart';
import 'package:golf_tracker_app/widgets/course_cards.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
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
                        child: CircularProgressIndicator(),
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
                  final bio = userData['bio'] ?? 'Add a bio to tell others about yourself...';

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
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<String?>(
                            future: FirestorageService().getProfileImageUrl(user?.uid ?? ''),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }

                              final url = snapshot.data;
                              if (url == null || url.isEmpty) {
                                return const CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.person, size: 40, color: Colors.white),
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
                                    color: bio.startsWith('Add') ? Colors.grey[400] : Colors.black87,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.edit,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
                              child: CircularProgressIndicator(),
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
                            final roundData = rounds[index].data() as Map<String, dynamic>;
                            final courseName = roundData['courseName'] ?? 'Unknown Course';
                            final score = roundData['score'] ?? 0;
                            final holes = roundData['holes'] ?? 18;
                            final par = roundData['par'] ?? 72;
                            final relativeToPar = score - par;

                            return CourseCard(
                              type: CourseCardType.courseScoreCard,
                              courseName: courseName,
                              courseImage: 'assets/images/default.png',
                              holes: holes,
                              par: par,
                              totalScore: score,
                              relativeToPar: relativeToPar,
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