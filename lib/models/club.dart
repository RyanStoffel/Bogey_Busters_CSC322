import 'package:golf_tracker_app/models/club_type.dart';

class Club {
  Club({
    required this.clubType,
    this.customDegree,
  });

  final ClubType clubType;
  final int? customDegree; // Only used for varWedge

  String get displayName {
    if (clubType == ClubType.varWedge && customDegree != null) {
      return '$customDegree° Wedge';
    }
    return clubType.displayName;
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'clubType': clubType.toJson(),
      'customDegree': customDegree,
    };
  }

  // Create from JSON
  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      clubType: ClubType.fromJson(json['clubType'] as String),
      customDegree: json['customDegree'] as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Club &&
        other.clubType == clubType &&
        other.customDegree == customDegree;
  }

  @override
  int get hashCode => clubType.hashCode ^ customDegree.hashCode;
}
