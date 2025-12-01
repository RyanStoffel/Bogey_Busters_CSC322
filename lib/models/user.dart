import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  User({
    required this.uid,
    required this.email,
    this.displayName,
    this.profilePictureUrl,
    this.handicap,
    this.favoriteCoursesIds,
    this.createdAt,
    this.isAdmin = false,
  });

  final String uid;
  final String email;
  String? displayName;
  String? profilePictureUrl;
  double? handicap;
  List<String>? favoriteCoursesIds;
  DateTime? createdAt;
  bool isAdmin;

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'profilePictureUrl': profilePictureUrl,
      'handicap': handicap,
      'favoriteCoursesIds': favoriteCoursesIds,
      'createdAt': createdAt?.toIso8601String(),
      'isAdmin': isAdmin,
    };
  }

  // Create from JSON from Firestore
  factory User.fromJson(Map<String, dynamic> json) {
    DateTime? createdAtDateTime;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is Timestamp) {
        createdAtDateTime = (json['createdAt'] as Timestamp).toDate();
      } else if (json['createdAt'] is String) {
        createdAtDateTime = DateTime.parse(json['createdAt'] as String);
      }
    }

    return User(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      handicap: (json['handicap'] as num?)?.toDouble(),
      favoriteCoursesIds: (json['favoriteCoursesIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      createdAt: createdAtDateTime,
      isAdmin: json['isAdmin'] as bool? ?? false,
    );
  }
}
