import 'package:golf_tracker_app/models/coordinate_point.dart';

class TeeBox {
  TeeBox({
    required this.tee,
    this.location,
    this.yards,
    this.par,
    this.handicap,
  });

  final String tee;
  CoordinatePoint? location; 
  int? yards; 
  int? par; 
  int? handicap;

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'tee': tee,
      'location': location?.toJson(),
    };
  }

  // Create from JSON
  factory TeeBox.fromJson(Map<String, dynamic> json) {
    return TeeBox(
      tee: json['tee'] as String,
      location: json['location'] != null
          ? CoordinatePoint.fromJson(json['location'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  String toString() => 'TeeBox(name: $tee, location: $location)';
}

