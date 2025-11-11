
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:golf_tracker_app/models/models.dart';

class OverpassApiService {
  //////////////////////////
  /// Instance Variables ///
  //////////////////////////
  
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';
  static const int _timeoutSeconds = 1000;
  static double _milesToMeters(double miles) => miles * 1609.34;

  ///////////////////////
  /// Utility Methods ///
  ///////////////////////
  
  Future<List<Course>> fetchNearbyCourses({
    required double latitude,
    required double longitude,
    double radiusInMiles = 25.0,
  }) async {
    try {
      final radiusInMeters = _milesToMeters(radiusInMiles);
      final query = _buildNearbyCoursesQuery(latitude, longitude, radiusInMeters);

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'text/plain'},
        body: query,
      ).timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseCourseData(data);
      } else {
        throw Exception('Failed to fetch courses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching nearby courses');
    }
  }


  Future<Course> fetchCourseDetails(String courseId) async {
    try {
      final query = _buildCourseDetailsQuery(courseId);
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'text/plain'},
        body: query,
      ).timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch course details: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final elements = data['elements'] as List<dynamic>;

      if (elements.isEmpty) {
        throw Exception('Course not found: $courseId');
      }

      return _parseCourseDetails(data, courseId);
    } catch (e) {
      throw Exception('$e');
    }
  }

  String _buildNearbyCoursesQuery(
    double latitude,
    double longitude,
    double radiusInMeters,
  ) {
    return '''
      [out:json][timeout:$_timeoutSeconds];
      (
        node["leisure"="golf_course"](around:$radiusInMeters,$latitude,$longitude);
        way["leisure"="golf_course"](around:$radiusInMeters,$latitude,$longitude);
        relation["leisure"="golf_course"](around:$radiusInMeters,$latitude,$longitude);
      );
      out center tags;
    ''';
  }

  String _buildCourseDetailsQuery(String courseId) {
    final cleanId = courseId.split('/');
    print(cleanId[1]);
    return '''
      [out:json][timeout:$_timeoutSeconds];
      // Get the golf course way
      way(${cleanId[1]});
      out center tags;
      // Store it for later reference
      way(${cleanId[1]})->.golfCourse;
      // Convert the way to an area for searching
      .golfCourse map_to_area->.searchArea;
      // Find all features within the golf course area
      (
        // Nodes with golf tags in the area
        node(area.searchArea)["golf"];
        // Ways with golf tags in the area
        way(area.searchArea)["golf"];
        // Water features
        way(area.searchArea)["natural"="water"];
        way(area.searchArea)["golf"="water_hazard"];
      );
      // Output the results
      out body;
      >;
      out skel qt;
    ''';
  }

  List<Course> _parseCourseData(Map<String, dynamic> data) {
    final List<Course> courses = [];
    final elements = data['elements'] as List<dynamic>? ?? [];

    for (var element in elements) {
      try {
        // Try to get a name from the response
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        final name = tags['name'] as String?;
        if (name == null || name.isEmpty) continue;

        // Try to get the lat/lon from the response
        double? lat;
        double? lon;

        if (element.containsKey('center')) {
          lat = element['center']['lat'] as double?;
          lon = element['center']['lon'] as double?;
        } else {
          lat = element['lat'] as double?;
          lon = element['lon'] as double?;
        }

        if (lat == null || lon == null) continue;

        // Build course ID from the type and ID
        final type = element['type'] as String? ?? 'node';
        final id = element['id'];
        final courseId = '$type/$id';

        // Extract address components
        final street = tags['addr:street'] as String?;
        final houseNumber = tags['addr:housenumber'] as String?;
        final city = tags['addr:city'] as String?;
        final state = tags['addr:state'] as String?;
        final postcode = tags['addr:postcode'] as String?;

        // Extract phone and website
        final phone = tags['phone'] as String?;
        final website = tags['website'] as String?;

        courses.add(Course(
          courseId: courseId,
          courseName: name,
          location: CoordinatePoint(latitude: lat, longitude: lon),
          courseStreetAddress: street,
          courseHouseNumber: houseNumber,
          courseCity: city,
          courseState: state,
          coursePostalCode: postcode,
          phoneNumber: phone,
          website: website
        ));
      } catch (e) {
        throw Exception('Error parsing course: $e');
      }
    }

    return courses;
  }

  Course _parseCourseDetails(Map<String, dynamic> data, String courseId) {
    final elements = data['elements'] as List<dynamic>? ?? [];

    Map<String, dynamic>? courseElement;
    for (var element in elements) {
      if (element['id'].toString() == courseId.replaceAll(RegExp(r'^(node|way|relation)/'), '')) {
        courseElement = element;
        break;
      }
    }

    if (courseElement == null) {
      throw Exception('Course not found in response');
    }

    final tags = courseElement['tags'] as Map<String, dynamic>? ?? {};
    final courseName = tags['name'] as String? ?? 'Unknown Course';

    double lat;
    double lon;
    if (courseElement.containsKey('center')) {
      lat = courseElement['center']['lat'] as double;
      lon = courseElement['center']['lon'] as double;
    } else {
      lat = courseElement['lat'] as double;
      lon = courseElement['lon'] as double;
    }

    final holes = _extractHoles(elements);

    int? totalPar;
    if (holes.isNotEmpty) {
      totalPar = holes.fold<int>(0, (sumOfPars, hole) => sumOfPars + (hole.par ?? 0));
    }

    return Course(
      courseId: courseId,
      courseName: courseName,
      location: CoordinatePoint(latitude: lat, longitude: lon),
      holes: holes.isEmpty ? null : holes,
      totalPar: totalPar,
      phoneNumber: tags['phone'] as String?,
      website: tags['website'] as String?,
      courseStreetAddress: tags['addr:street'] as String?,
      courseHouseNumber: tags['addr:housenumber'] as String?,
      courseCity: tags['addr:city'] as String?,
      courseState: tags['addr:state'] as String?,
      coursePostalCode: tags['addr:postcode'] as String?,
    );
  }

  List<Hole> _extractHoles(List<dynamic> elements) {
    try {
      final Map<int, Hole> holes = {};
      final List<TeeBox> unassignedTees = [];
      final List<CoordinatePoint> unassignedGreens = [];

      // First pass to find hole markers
      for (var element in elements) {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};

        if (tags['golf'] == 'hole') {
          final holeNumber = int.tryParse(tags['ref']?.toString() ?? '');
          if (holeNumber != null) {
            int? par = int.tryParse(tags['par']?.toString() ?? '');
            final handicap = int.tryParse(tags['handicap']?.toString() ?? '');

            holes[holeNumber] = Hole(
              holeNumber: holeNumber,
              par: par,
              handicap: handicap,
              teeBoxes: [],
              greenCoordinates: [],
              greenLocation: null,
              hazards: [],
            );
          }
        }
      }

      // Second pass to find tee boxes, greens, hazards, fairways, and rough
      for (var element in elements) {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};

        if (tags['golf'] == 'tee') {
          final holeNumber = int.tryParse(tags['ref']?.toString() ?? '');
          final tee = tags['tee'] as String? ?? 'Unkown';

          double? lat = element['lat'] as double?;
          double? lon = element['lon'] as double?;

          final teeBox = TeeBox(
            tee: tee,
            location: CoordinatePoint(latitude: lat, longitude: lon),
          );

          if (holeNumber != null && holes.containsKey(holeNumber)) {
            holes[holeNumber]!.teeBoxes?.add(teeBox);
          } else {
            unassignedTees.add(teeBox);
          }
        }

        if (tags['golf'] == 'green') {
          final holeNumber = int.tryParse(tags['ref']?.toString() ?? '');

          double? lat = element['lat'] as double?;
          double? lon = element['lon'] as double?;

          final greenCoordinatePoint = CoordinatePoint(latitude: lat, longitude: lon);

          if (holeNumber != null && holes.containsKey(holeNumber)) {
            holes[holeNumber]!.greenLocation = greenCoordinatePoint;
          } else {
            unassignedGreens.add(greenCoordinatePoint);
          }
        }
      }

      final holesList = holes.values.toList();
      holesList.sort((a, b) => a.holeNumber.compareTo(b.holeNumber));
      return holesList;
    } catch (e) {
      throw Exception('Error extracting holes from response.');
    }
  }
}