import 'package:golf_tracker_app/models/club.dart';
import 'package:golf_tracker_app/models/coordinate_point.dart';

class Shot {
  Shot({
    required this.shotNumber,
    required this.clubUsed,
    required this.location,
    this.distanceToTarget,
    this.distanceFromPrevious,
    this.timestamp,
  });

  final int shotNumber;
  final Club clubUsed;
  final CoordinatePoint location;
  double? distanceToTarget; 
  double? distanceFromPrevious;
  DateTime? timestamp;

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'shotNumber': shotNumber,
      'clubUsed': clubUsed.toJson(),
      'location': location.toJson(),
      'distanceToTarget': distanceToTarget,
      'distanceFromPrevious': distanceFromPrevious,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  // Create from JSON
  factory Shot.fromJson(Map<String, dynamic> json) {
    return Shot(
      shotNumber: json['shotNumber'] as int,
      clubUsed: Club.fromJson(json['clubUsed'] as Map<String, dynamic>),
      location: CoordinatePoint.fromJson(json['location'] as Map<String, dynamic>),
      distanceToTarget: json['distanceToTarget'] as double?,
      distanceFromPrevious: json['distanceFromPrevious'] as double?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }
}
