import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/services/firestorage_service.dart';

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

  @override
  void initState() {
    super.initState();
    _profileUrl = FirestorageService().getProfileImageUrl(FirebaseAuth.instance.currentUser?.uid ?? '');
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
        context.go('/in-round-screen'); //CHANGE BACK TO /play WHEN DONE
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