import 'package:golf_tracker_app/models/coordinate_point.dart';

class TeeBox {
  TeeBox({
    required this.name,
    this.location,
    this.yards,
    this.par,
    this.handicap,
  });

  final String name; // e.g., "Championship", "Back", "Middle", "Front", "Forward"
  CoordinatePoint? location; // Tee box coordinates
  int? yards; // Yardage from this tee
  int? par; // Par for this hole from this tee (usually same, but can vary)
  int? handicap; // Handicap/hole difficulty

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'location': location?.toJson(),
      'yards': yards,
      'par': par,
      'handicap': handicap,
    };
  }

  // Create from JSON
  factory TeeBox.fromJson(Map<String, dynamic> json) {
    return TeeBox(
      name: json['name'] as String,
      location: json['location'] != null
          ? CoordinatePoint.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      yards: json['yards'] as int?,
      par: json['par'] as int?,
      handicap: json['handicap'] as int?,
    );
  }

  @override
  String toString() => 'TeeBox(name: $name, location: $location, yards: $yards)';
}

