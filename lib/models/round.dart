import 'package:golf_tracker_app/models/hole.dart';

class Round {
  Round({
    required this.roundId,
    required this.userId,
    required this.courseId,
    required this.courseName,
    required this.date,
    this.holes,
    this.totalScore,
    this.totalPar,
    this.relativeToPar,
    this.duration,
    this.teeColor,
    this.playingPartners,
    this.weatherConditions,
    this.isCompleted = false,
  });

  final String roundId;
  final String userId;
  final String courseId;
  final String courseName;
  final DateTime date;
  List<Hole>? holes;
  int? totalScore;
  int? totalPar;
  int? relativeToPar;
  Duration? duration;
  String? teeColor; // Blue, White, Red, Gold, etc.
  List<String>? playingPartners;
  String? weatherConditions;
  bool isCompleted;

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'roundId': roundId,
      'userId': userId,
      'courseId': courseId,
      'courseName': courseName,
      'date': date.toIso8601String(),
      'holes': holes?.map((h) => h.toJson()).toList(),
      'totalScore': totalScore,
      'totalPar': totalPar,
      'relativeToPar': relativeToPar,
      'duration': duration?.inMinutes,
      'teeColor': teeColor,
      'playingPartners': playingPartners,
      'weatherConditions': weatherConditions,
      'isCompleted': isCompleted,
    };
  }

  // Create from JSON
  factory Round.fromJson(Map<String, dynamic> json) {
    return Round(
      roundId: json['roundId'] as String,
      userId: json['userId'] as String,
      courseId: json['courseId'] as String,
      courseName: json['courseName'] as String,
      date: DateTime.parse(json['date'] as String),
      holes: (json['holes'] as List<dynamic>?)
          ?.map((h) => Hole.fromJson(h as Map<String, dynamic>))
          .toList(),
      totalScore: json['totalScore'] as int?,
      totalPar: json['totalPar'] as int?,
      relativeToPar: json['relativeToPar'] as int?,
      duration: json['duration'] != null
          ? Duration(minutes: json['duration'] as int)
          : null,
      teeColor: json['teeColor'] as String?,
      playingPartners: (json['playingPartners'] as List<dynamic>?)
          ?.map((p) => p as String)
          .toList(),
      weatherConditions: json['weatherConditions'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}