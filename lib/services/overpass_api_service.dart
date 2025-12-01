import 'dart:convert';
import 'dart:math';

import 'package:golf_tracker_app/models/models.dart';
import 'package:http/http.dart' as http;

class OverpassApiService {
  //////////////////////////
  /// Instance Variables ///
  //////////////////////////

  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';
  static const int _timeoutSeconds = 30;
  static double _milesToMeters(double miles) => miles * 1609.34;

  /// Calculate distance between two coordinate points in yards using Haversine formula
  static int _calculateDistanceInYards(CoordinatePoint point1, CoordinatePoint point2) {
    const earthRadiusInMeters = 6371000.0; // Earth's radius in meters

    final lat1 = point1.latitude ?? 0.0;
    final lon1 = point1.longitude ?? 0.0;
    final lat2 = point2.latitude ?? 0.0;
    final lon2 = point2.longitude ?? 0.0;

    final lat1Rad = lat1 * (pi / 180.0);
    final lat2Rad = lat2 * (pi / 180.0);
    final deltaLat = (lat2 - lat1) * (pi / 180.0);
    final deltaLon = (lon2 - lon1) * (pi / 180.0);

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * asin(sqrt(a));

    final distanceInMeters = earthRadiusInMeters * c;
    final distanceInYards = (distanceInMeters * 1.09361).round(); // Convert meters to yards

    return distanceInYards;
  }

  ///////////////////////
  /// Utility Methods ///
  ///////////////////////

  Future<List<Course>> fetchNearbyCourses({
    required double latitude,
    required double longitude,
    double radiusInMiles = 50.0,
  }) async {
    try {
      final radiusInMeters = _milesToMeters(radiusInMiles);
      final query = _buildNearbyCoursesQuery(latitude, longitude, radiusInMeters);

      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'text/plain'},
            body: query,
          )
          .timeout(Duration(seconds: _timeoutSeconds));

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
    const maxRetries = 3;
    int attempts = 0;
    Exception? lastError;

    while (attempts < maxRetries) {
      try {
        attempts++;
        print('Fetching course details for $courseId (attempt $attempts/$maxRetries)');
        
        final query = _buildCourseDetailsQuery(courseId);
        final response = await http
            .post(
              Uri.parse(_baseUrl),
              headers: {'Content-Type': 'text/plain'},
              body: query,
            )
            .timeout(Duration(seconds: _timeoutSeconds));

        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
        }

        final data = json.decode(response.body);
        final elements = data['elements'] as List<dynamic>;

        if (elements.isEmpty) {
          throw Exception('No data returned for course: $courseId');
        }

        final course = _parseCourseDetails(data, courseId);
        print('Successfully fetched details for ${course.courseName}');
        return course;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print('Error fetching course details for $courseId (attempt $attempts): $e');
        
        if (attempts < maxRetries) {
          // Wait before retrying with exponential backoff
          await Future.delayed(Duration(seconds: attempts));
          print('Retrying...');
        }
      }
    }

    throw Exception('Failed to fetch course $courseId after $maxRetries attempts: ${lastError.toString()}');
  }

  String _buildNearbyCoursesQuery(
    double latitude,
    double longitude,
    double radiusInMeters,
  ) {
    return '''
      [out:json][timeout:$_timeoutSeconds];
      (
        node["leisure"="golf_course"]["BBA"="true"](around:$radiusInMeters,$latitude,$longitude);
        way["leisure"="golf_course"]["BBA"="true"](around:$radiusInMeters,$latitude,$longitude);
        relation["leisure"="golf_course"]["BBA"="true"](around:$radiusInMeters,$latitude,$longitude);
      );
      out center tags;
    ''';
  }

  String _buildCourseDetailsQuery(String courseId) {
    final cleanId = courseId.split('/');
    final type = cleanId[0];
    final id = cleanId[1];
    print('Fetching $type/$id');
    return '''
      [out:json][timeout:$_timeoutSeconds];
      // Get the golf course way
      $type($id);
      out center tags;
      // Store it for later reference
      $type($id)->.golfCourse;
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
            website: website));
      } catch (e) {
        throw Exception('Error parsing course: $e');
      }
    }

    return courses;
  }

  Course _parseCourseDetails(Map<String, dynamic> data, String courseId) {
    final elements = data['elements'] as List<dynamic>? ?? [];

    // Find the main course element
    Map<String, dynamic>? courseElement;
    for (var element in elements) {
      if (element['id'].toString() ==
          courseId.replaceAll(RegExp(r'^(node|way|relation)/'), '')) {
        courseElement = element;
        break;
      }
    }

    if (courseElement == null) {
      throw Exception('Course not found in response');
    }

    final tags = courseElement['tags'] as Map<String, dynamic>? ?? {};
    final courseName = tags['name'] as String? ?? 'Unknown Course';

    // Safely parse numeric fields - OSM data can be string or int
    // Check multiple possible tag names for each field
    final totalPar = int.tryParse(tags['total_par']?.toString() ?? '') ??
        int.tryParse(tags['golf:course:par']?.toString() ?? '');

    // For rating, check multiple tags and take first value if it's a range
    String? ratingStr = tags['rating']?.toString() ?? tags['golf:course:rating']?.toString();
    double? rating;
    if (ratingStr != null) {
      // Take first value if it's a range (e.g., "72.5-75.2" -> "72.5")
      final firstValue = ratingStr.split(RegExp(r'[-;,]')).first.trim();
      rating = double.tryParse(firstValue);
    }

    // For slope, check multiple tags and take first value if it's a range
    String? slopeStr = tags['slope']?.toString() ?? tags['golf:course:slope']?.toString();
    int? slope;
    if (slopeStr != null) {
      // Take first value if it's a range (e.g., "130-140" -> "130")
      final firstValue = slopeStr.split(RegExp(r'[-;,]')).first.trim();
      slope = int.tryParse(firstValue);
    }

    // For yards/length, check multiple tags and take first value if it's a range
    String? yardsStr = tags['total_yards']?.toString() ?? tags['golf:course:length']?.toString();
    int? totalYards;
    if (yardsStr != null) {
      // Take first value if it's a range (e.g., "6500-7200" -> "6500")
      final firstValue = yardsStr.split(RegExp(r'[-;,]')).first.trim();
      totalYards = int.tryParse(firstValue);
    }

    double lat;
    double lon;
    if (courseElement.containsKey('center')) {
      lat = courseElement['center']['lat'] as double;
      lon = courseElement['center']['lon'] as double;
    } else {
      lat = courseElement['lat'] as double;
      lon = courseElement['lon'] as double;
    }

    // Create a map of node IDs to coordinates
    final Map<int, Map<String, double>> nodeCoordinates = {};
    for (var element in elements) {
      if (element['type'] == 'node') {
        final id = element['id'] as int;
        final nodeLat = element['lat'] as double;
        final nodeLon = element['lon'] as double;
        nodeCoordinates[id] = {'lat': nodeLat, 'lon': nodeLon};
      }
    }

    final holes = _extractHolesFromWays(elements, nodeCoordinates);

    int? totalParCalculated;
    if (holes.isNotEmpty) {
      totalParCalculated = holes.fold<int>(0, (sum, hole) => sum + (hole.par ?? 0));
    }

    return Course(
      courseId: courseId,
      courseName: courseName,
      location: CoordinatePoint(latitude: lat, longitude: lon),
      holes: holes.isEmpty ? null : holes,
      totalPar: totalPar ?? totalParCalculated,
      totalYards: totalYards,
      rating: rating,
      slope: slope,
      phoneNumber: tags['phone'] as String?,
      website: tags['website'] as String?,
      courseStreetAddress: tags['addr:street'] as String?,
      courseHouseNumber: tags['addr:housenumber'] as String?,
      courseCity: tags['addr:city'] as String?,
      courseState: tags['addr:state'] as String?,
      coursePostalCode: tags['addr:postcode'] as String?,
    );
  }

  List<Hole> _extractHolesFromWays(
    List<dynamic> elements,
    Map<int, Map<String, double>> nodeCoordinates,
  ) {
    try {
      final Map<int, Hole> holes = {};

      // Group elements by hole number
      final Map<int, List<Map<String, dynamic>>> holeElements = {};

      for (var element in elements) {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};

        // Get hole number from either 'hole' or 'ref' tag
        String? holeNumberStr = tags['hole'] as String?;
        if (holeNumberStr == null) {
          holeNumberStr = tags['ref'] as String?;
        }

        if (holeNumberStr != null) {
          final holeNumber = int.tryParse(holeNumberStr);
          if (holeNumber != null) {
            holeElements.putIfAbsent(holeNumber, () => []);
            holeElements[holeNumber]!.add(element);
          }
        }
      }

      // Process each hole
      for (var holeNumber in holeElements.keys) {
        final elements = holeElements[holeNumber]!;

        // Extract hole metadata, tees, and greens
        int? par;
        int? handicap;
        List<TeeBox> teeBoxes = [];
        CoordinatePoint? greenLocation;
        List<CoordinatePoint>? greenCoordinates;

        // First pass: collect all tee boxes and find the green location
        for (var element in elements) {
          final tags = element['tags'] as Map<String, dynamic>? ?? {};
          final golfType = tags['golf'] as String?;

          // Get par and handicap from golf:hole elements or any element with these tags
          if (tags.containsKey('par') && par == null) {
            par = int.tryParse(tags['par']?.toString() ?? '');
          }
          if (tags.containsKey('handicap') && handicap == null) {
            handicap = int.tryParse(tags['handicap']?.toString() ?? '');
          }

          if (golfType == 'tee') {
            final teeColor = tags['tee'] as String? ?? 'unknown';
            final coords = _calculateCenterFromWay(element, nodeCoordinates);

            // Try to get yardage from various possible tags
            int? yards;

            // Check for direct yardage tags
            if (tags.containsKey('yards')) {
              yards = int.tryParse(tags['yards']?.toString() ?? '');
            } else if (tags.containsKey('distance')) {
              yards = int.tryParse(tags['distance']?.toString() ?? '');
            } else if (tags.containsKey('length')) {
              // Length might be in yards or meters, try to parse
              final lengthStr = tags['length']?.toString() ?? '';
              yards = int.tryParse(lengthStr);
            } else if (tags.containsKey('metres') || tags.containsKey('meters')) {
              // Convert meters to yards (1 meter = 1.09361 yards)
              final metersStr = (tags['metres'] ?? tags['meters'])?.toString() ?? '';
              final meters = int.tryParse(metersStr);
              if (meters != null) {
                yards = (meters * 1.09361).round();
              }
            }

            // Also check for tee-specific length tag patterns used in OSM
            // Example: length:blue, length:white, etc.
            if (yards == null && tags.containsKey('length:$teeColor')) {
              yards = int.tryParse(tags['length:$teeColor']?.toString() ?? '');
            }

            if (coords != null) {
              teeBoxes.add(TeeBox(
                tee: teeColor,
                location: coords,
                yards: yards,
                par: par,
                handicap: handicap,
              ));
            }
          } else if (golfType == 'green') {
            final coords = _calculateCenterFromWay(element, nodeCoordinates);
            if (coords != null) {
              greenLocation = coords;
            }

            // Also get polygon coordinates
            final polyCoords = _getPolygonCoordinates(element, nodeCoordinates);
            if (polyCoords != null && polyCoords.isNotEmpty) {
              greenCoordinates = polyCoords;
            }
          }
        }

        // Second pass: calculate missing yardages using tee-to-green distance
        if (greenLocation != null) {
          final green = greenLocation; // Create non-nullable local variable for type promotion
          for (int i = 0; i < teeBoxes.length; i++) {
            if (teeBoxes[i].yards == null && teeBoxes[i].location != null) {
              final calculatedYards = _calculateDistanceInYards(
                teeBoxes[i].location!,
                green,
              );
              // Create a new TeeBox with the calculated yardage
              teeBoxes[i] = TeeBox(
                tee: teeBoxes[i].tee,
                location: teeBoxes[i].location,
                yards: calculatedYards,
                par: teeBoxes[i].par,
                handicap: teeBoxes[i].handicap,
              );
            }
          }
        }

        holes[holeNumber] = Hole(
          holeNumber: holeNumber,
          par: par,
          handicap: handicap,
          teeBoxes: teeBoxes.isEmpty ? null : teeBoxes,
          greenLocation: greenLocation,
          greenCoordinates: greenCoordinates,
        );
      }

      final holesList = holes.values.toList();
      holesList.sort((a, b) => a.holeNumber.compareTo(b.holeNumber));
      return holesList;
    } catch (e) {
      throw Exception('Error extracting holes from response: $e');
    }
  }

  CoordinatePoint? _calculateCenterFromWay(
    Map<String, dynamic> element,
    Map<int, Map<String, double>> nodeCoordinates,
  ) {
    final nodes = element['nodes'] as List<dynamic>?;
    if (nodes == null || nodes.isEmpty) return null;

    double latSum = 0;
    double lonSum = 0;
    int validNodes = 0;

    for (var nodeId in nodes) {
      final coords = nodeCoordinates[nodeId as int];
      if (coords != null) {
        latSum += coords['lat']!;
        lonSum += coords['lon']!;
        validNodes++;
      }
    }

    if (validNodes == 0) return null;

    return CoordinatePoint(
      latitude: latSum / validNodes,
      longitude: lonSum / validNodes,
    );
  }

  List<CoordinatePoint>? _getPolygonCoordinates(
    Map<String, dynamic> element,
    Map<int, Map<String, double>> nodeCoordinates,
  ) {
    final nodes = element['nodes'] as List<dynamic>?;
    if (nodes == null || nodes.isEmpty) return null;

    final List<CoordinatePoint> coordinates = [];

    for (var nodeId in nodes) {
      final coords = nodeCoordinates[nodeId as int];
      if (coords != null) {
        coordinates.add(CoordinatePoint(
          latitude: coords['lat']!,
          longitude: coords['lon']!,
        ));
      }
    }

    return coordinates.isEmpty ? null : coordinates;
  }
}
