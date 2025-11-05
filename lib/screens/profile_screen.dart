import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:golf_tracker_app/services/firestorage_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(user?.displayName ?? 'Profile'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<String?>(
              future: FirestorageService().getProfileImageUrl(user?.uid ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 150,
                    height: 150,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final url = snapshot.data;
                if (url == null || url.isEmpty) {
                  return const CircleAvatar(
                    radius: 75,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 60, color: Colors.white),
                  );
                }

                return CircleAvatar(
                  radius: 75,
                  backgroundImage: NetworkImage(url),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              user?.displayName ?? user?.email ?? 'No name',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
