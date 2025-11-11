import 'package:geolocator/geolocator.dart';

class LocationService {
  /* 


       HARDCODED LOCATION!!!!


  */
  static const double _cbuLatitude = 33.9297;
  static const double _cbuLongitude = -117.2864;


  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled. Using hardcoded CBU location.');
      // Return hardcoded CBU location for emulator
      return Position(
        latitude: _cbuLatitude,
        longitude: _cbuLongitude,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied. Using hardcoded CBU location.');
        // Return hardcoded CBU location for emulator
        return Position(
          latitude: _cbuLatitude,
          longitude: _cbuLongitude,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied. Using hardcoded CBU location.');
      // Return hardcoded CBU location for emulator
      return Position(
        latitude: _cbuLatitude,
        longitude: _cbuLongitude,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      print('Error getting location: $e. Using hardcoded CBU location.');
      // Return hardcoded CBU location if there's an error (common on emulators)
      return Position(
        latitude: _cbuLatitude,
        longitude: _cbuLongitude,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }
  }

  double getDistanceInMiles(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    double distanceInMeters = Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );

    double distanceInMiles = distanceInMeters / 1609.34;

    return distanceInMiles;
  }

  String formatDistance(double miles) {
    if (miles < 0.1) {
      int feet = (miles * 5280).round();
      return '$feet ft';
    } else if (miles < 10) {
      return '${miles.toStringAsFixed(1)}';
    } else {
      return '${miles.round()}';
    }
  }

  Future<String?> getDistanceToCourse(
    double courseLatitude,
    double courseLongitude,
  ) async {
    print('LocationService: Getting distance to course at lat=$courseLatitude, lng=$courseLongitude');
    Position? currentPosition = await getCurrentLocation();

    if (currentPosition == null) {
      print('LocationService: Could not get current position');
      return null;
    }

    print('LocationService: Current position: lat=${currentPosition.latitude}, lng=${currentPosition.longitude}');

    double miles = getDistanceInMiles(
      currentPosition.latitude,
      currentPosition.longitude,
      courseLatitude,
      courseLongitude,
    );

    print('LocationService: Distance calculated: $miles miles');

    return formatDistance(miles);
  }
}