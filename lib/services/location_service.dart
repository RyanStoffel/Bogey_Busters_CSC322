import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied');
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
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
    Position? currentPosition = await getCurrentLocation();

    if (currentPosition == null) {
      return null;
    }

    double miles = getDistanceInMiles(
      currentPosition.latitude,
      currentPosition.longitude,
      courseLatitude,
      courseLongitude,
    );

    return formatDistance(miles);
  }
}