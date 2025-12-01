class CoordinatePoint {
  CoordinatePoint({
    required this.latitude,
    required this.longitude,
  });

  double? latitude;
  double? longitude;

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Create from JSON
  factory CoordinatePoint.fromJson(Map<String, dynamic> json) {
    return CoordinatePoint(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() => 'CoordinatePoint(lat: $latitude, lng: $longitude)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoordinatePoint &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}
