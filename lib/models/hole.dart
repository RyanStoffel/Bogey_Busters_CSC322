import 'package:golf_tracker_app/models/coordinate_point.dart';
import 'package:golf_tracker_app/models/tee_box.dart';

class Hole {
  Hole({
    required this.holeNumber,
    required this.par,
    this.handicap, 
    this.yards,
    this.teeBoxes, 
    this.greenLocation, 
    this.greenCoordinates, 
    this.hazards,
  });

  final int holeNumber;
  final int par;
  int? handicap; 
  int? yards;
  List<TeeBox>? teeBoxes; 
  CoordinatePoint? greenLocation; 
  List<CoordinatePoint>? greenCoordinates; 
  List<CoordinatePoint>? hazards; 

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'holeNumber': holeNumber,
      'par': par,
      'handicap': handicap,
      'yards': yards,
      'teeBoxes': teeBoxes?.map((t) => t.toJson()).toList(),
      'greenLocation': greenLocation?.toJson(),
      'greenCoordinates': greenCoordinates?.map((c) => c.toJson()).toList(),
      'hazards': hazards?.map((h) => h.toJson()).toList(),
    };
  }

  // Create from JSON
  factory Hole.fromJson(Map<String, dynamic> json) {
    return Hole(
      holeNumber: json['holeNumber'] as int,
      par: json['par'] as int,
      handicap: json['handicap'] as int?,
      yards: json['yards'] as int?,
      teeBoxes: (json['teeBoxes'] as List<dynamic>?)
          ?.map((t) => TeeBox.fromJson(t as Map<String, dynamic>))
          .toList(),
      greenLocation: json['greenLocation'] != null
          ? CoordinatePoint.fromJson(json['greenLocation'] as Map<String, dynamic>)
          : null,
      greenCoordinates: (json['greenCoordinates'] as List<dynamic>?)
          ?.map((c) => CoordinatePoint.fromJson(c as Map<String, dynamic>))
          .toList(),
      hazards: (json['hazards'] as List<dynamic>?)
          ?.map((h) => CoordinatePoint.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }
}