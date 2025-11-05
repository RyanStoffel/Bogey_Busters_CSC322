import 'package:firebase_storage/firebase_storage.dart';

class FirestorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Returns a download URL for the profile picture at
  /// `profile_pictures/{uid}.jpg` or `null` if not available.
  Future<String?> getProfileImageUrl(String uid) async {
    try {
      final ref = _storage.ref().child('profile_pictures/$uid.jpg');

      // Check metadata first to avoid throwing on missing file
      try {
        await ref.getMetadata();
      } catch (e) {
        return null;
      }

      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}
