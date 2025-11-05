import 'package:golf_tracker_app/models/hole.dart';
import 'package:golf_tracker_app/models/coordinate_point.dart';

class Course {
  Course({
    required this.courseId,
    required this.courseName,
    required this.location,
    this.courseStreetAddress,
    this.courseHouseNumber,
    this.courseCity,
    this.courseState,
    this.coursePostalCode,
    this.holes,
    this.totalPar,
    this.totalYards,
    this.rating,
    this.slope,
    this.phoneNumber,
    this.website,
    this.courseBoundary,
  });

  final String courseId;
  final String courseName;
  final CoordinatePoint location;
  String? courseStreetAddress;
  String? courseHouseNumber; 
  String? courseCity;
  String? courseState;
  String? coursePostalCode; 
  List<Hole>? holes; 
  int? totalPar;
  int? totalYards;
  double? rating; 
  int? slope; 
  String? phoneNumber;
  String? website;
  List<List<CoordinatePoint>>? courseBoundary;

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'location': location.toJson(),
      'courseStreetAddress': courseStreetAddress,
      'courseHouseNumber': courseHouseNumber,
      'courseCity': courseCity,
      'courseState': courseState,
      'coursePostalCode': coursePostalCode,
      'holes': holes?.map((h) => h.toJson()).toList(),
      'totalPar': totalPar,
      'totalYards': totalYards,
      'rating': rating,
      'slope': slope,
      'phoneNumber': phoneNumber,
      'website': website,
      'courseBoundary': courseBoundary?.map((polygon) => 
        polygon.map((c) => c.toJson()).toList()
      ).toList(),
    };
  }

  // Create from JSON
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      courseId: json['courseId'] as String,
      courseName: json['courseName'] as String,
      location: CoordinatePoint.fromJson(json['location'] as Map<String, dynamic>),
      courseStreetAddress: json['courseStreetAddress'] as String?,
      courseHouseNumber: json['courseHouseNumber'] as String?,
      courseCity: json['courseCity'] as String?,
      courseState: json['courseState'] as String?,
      coursePostalCode: json['coursePostalCode'] as String?,
      holes: (json['holes'] as List<dynamic>?)
          ?.map((h) => Hole.fromJson(h as Map<String, dynamic>))
          .toList(),
      totalPar: json['totalPar'] as int?,
      totalYards: json['totalYards'] as int?,
      rating: json['rating'] as double?,
      slope: json['slope'] as int?,
      phoneNumber: json['phoneNumber'] as String?,
      website: json['website'] as String?,
      courseBoundary: (json['courseBoundary'] as List<dynamic>?)?.map((polygon) => 
        (polygon as List<dynamic>).map((c) => 
          CoordinatePoint.fromJson(c as Map<String, dynamic>)
        ).toList()
      ).toList(),
    );
  }
}