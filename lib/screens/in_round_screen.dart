import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/models/models.dart';
import 'package:golf_tracker_app/services/overpass_api_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:live_activities/live_activities.dart';

class InRoundScreen extends StatefulWidget {
  final Course course;
  final String teeColor;

  const InRoundScreen({
    super.key,
    required this.course,
    required this.teeColor,
  });

  @override
  State<InRoundScreen> createState() => _InRoundScreenState();
}

class _InRoundScreenState extends State<InRoundScreen>
    with SingleTickerProviderStateMixin {
  late GoogleMapController mapController;
  final OverpassApiService _overpassApiService = OverpassApiService();
  final _liveActivitiesPlugin = LiveActivities();
  String? _activityId;

  // Store all markers and polygons, but only display current hole
  final Map<int, Set<Marker>> _holeMarkers = {};
  final Map<int, Set<Polygon>> _holePolygons = {};

  bool _isLoadingHoleData = true;
  List<Hole>? _holes;
  int _currentHoleIndex = 0;

  // Score tracking for current hole
  int? _currentScore;
  int? _currentPutts;

  // Track scores for all holes (holeNumber -> score)
  Map<int, int> _holeScores = {};

  // Current location tracking
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  Set<Polyline> _polylines = {};
  double? _distanceToGreen;

  // Custom marker for user location
  BitmapDescriptor? _userLocationIcon;

  // Animation for live indicator
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Future<void> startLiveActivity({
    required int holeNumber,
    required int distanceToGreen,
    required int relativeToPar,
    required String courseName,
  }) async {
    final activityData = {
      'holeNumber': holeNumber,
      'distanceToGreen': distanceToGreen,
      'relativeToPar': relativeToPar,
      'courseName': courseName,
    };

    _activityId = await _liveActivitiesPlugin.createActivity(activityData);
  }

  Future<void> updateLiveActivity({
    required int holeNumber,
    required int distanceToGreen,
    required int relativeToPar,
    required String courseName,
  }) async {
    if (_activityId == null) return;

    final activityData = {
      'holeNumber': holeNumber,
      'distanceToGreen': distanceToGreen,
      'relativeToPar': relativeToPar,
      'courseName': courseName,
    };

    await _liveActivitiesPlugin.updateActivity(_activityId!, activityData);
  }

  void _updateLiveActivity() {
    if (_activityId != null && currentHole != null) {
      updateLiveActivity(
        holeNumber: currentHole!.holeNumber,
        distanceToGreen: _distanceToGreen?.round() ?? 0,
        relativeToPar: _relativeToPar,
        courseName: widget.course.courseName,
      );
    }
  }

  Future<void> endLiveActivity() async {
    if (_activityId == null) return;
    await _liveActivitiesPlugin.endActivity(_activityId!);
    _activityId = null;
  }

  void _endLiveActivity() {
    endLiveActivity();
  }

  @override
  void initState() {
    super.initState();

    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _createCustomMarkers();
    _loadCourseData();
    _startLocationTracking();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (currentHole != null) {
        startLiveActivity(
          holeNumber: currentHole!.holeNumber,
          distanceToGreen: _distanceToGreen?.round() ?? 0,
          relativeToPar: _relativeToPar,
          courseName: widget.course.courseName,
        );
      }
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _pulseController.dispose();
    endLiveActivity();
    super.dispose();
  }

  Future<void> _createCustomMarkers() async {
    // Create a custom icon for user location programmatically
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..isAntiAlias = true;

    const size = 48.0;

    // Draw outer circle (shadow)
    paint.color = Colors.black.withOpacity(0.3);
    canvas.drawCircle(
      const Offset(size / 2, size / 2 + 2),
      size / 2 - 4,
      paint,
    );

    // Draw main circle (yellow/gold)
    paint.color = Colors.yellow.shade700;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 4,
      paint,
    );

    // Draw white inner circle (golf ball look)
    paint.color = Colors.white;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 8,
      paint,
    );

    // Draw border
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    paint.color = Colors.yellow.shade900;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 8,
      paint,
    );

    // Draw small dot in center
    paint.style = PaintingStyle.fill;
    paint.color = Colors.yellow.shade700;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      3,
      paint,
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    _userLocationIcon = BitmapDescriptor.bytes(buffer);

    if (mounted) {
      setState(() {});
    }
  }

  void _startLocationTracking() async {
    // Get initial position immediately
    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = initialPosition;
        });
        _updateDistanceToGreen();
        _updatePolylineToGreen();
      }
    } catch (e) {
      print('Error getting initial position: $e');
    }

    // Then start listening for updates
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        _updateDistanceToGreen();
        _updatePolylineToGreen();
      }
    });
  }

  void _updateDistanceToGreen() {
    if (currentHole?.greenLocation == null || _currentPosition == null) {
      if (mounted) {
        setState(() {
          _distanceToGreen = null;
        });
      }
      return;
    }

    final green = currentHole!.greenLocation!;
    final distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      green.latitude!,
      green.longitude!,
    );

    if (mounted) {
      setState(() {
        _distanceToGreen = distanceInMeters * 1.09361;
      });

      _updateLiveActivity();
    }
  }

  void _updatePolylineToGreen() {
    if (currentHole?.greenLocation == null || _currentPosition == null) {
      if (mounted) {
        setState(() {
          _polylines.clear();
        });
      }
      return;
    }

    final green = currentHole!.greenLocation!;

    if (mounted) {
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('distance_line'),
            points: [
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              LatLng(green.latitude!, green.longitude!),
            ],
            color: Colors.yellow.shade700,
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        };
      });
    }
  }

  // Get markers and polygons for current hole only
  Set<Marker> get _currentMarkers {
    final currentHoleNum = currentHole?.holeNumber;
    if (currentHoleNum == null) return {};

    // Add user location marker
    final markers = Set<Marker>.from(_holeMarkers[currentHoleNum] ?? {});

    if (_currentPosition != null && _userLocationIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: _userLocationIcon!,
          infoWindow: const InfoWindow(
            title: 'Your Location',
          ),
          anchor: const Offset(0.5, 0.5), // Center the marker
        ),
      );
    }

    return markers;
  }

  Set<Polygon> get _currentPolygons {
    final currentHoleNum = currentHole?.holeNumber;
    if (currentHoleNum == null) return {};
    return _holePolygons[currentHoleNum] ?? {};
  }

  Hole? get currentHole {
    if (_holes == null || _holes!.isEmpty) return null;
    return _holes![_currentHoleIndex];
  }

  TeeBox? get currentTeeBox {
    if (currentHole?.teeBoxes == null) return null;

    // Try to find exact match first
    var teeBox = currentHole!.teeBoxes!.firstWhere(
      (tee) => tee.tee.toLowerCase() == widget.teeColor.toLowerCase(),
      orElse: () {
        // Try to find a shared tee that contains this color
        return currentHole!.teeBoxes!.firstWhere(
          (tee) => tee.tee
              .toLowerCase()
              .split(';')
              .map((c) => c.trim())
              .contains(widget.teeColor.toLowerCase()),
          orElse: () => currentHole!.teeBoxes!.first,
        );
      },
    );

    return teeBox;
  }

  int get _relativeToPar {
    int totalScore = 0;
    int totalPar = 0;

    _holeScores.forEach((holeNumber, score) {
      totalScore += score;
      final hole = _holes?.firstWhere((h) => h.holeNumber == holeNumber);
      totalPar += hole?.par ?? 0;
    });

    return totalScore - totalPar;
  }

  Future<void> _loadCourseData() async {
    setState(() {
      _isLoadingHoleData = true;
    });

    try {
      print('Fetching course details for ${widget.course.courseId}');
      final courseDetails = await _overpassApiService.fetchCourseDetails(
        widget.course.courseId,
      );

      final holes = courseDetails.holes ?? [];
      print('Found ${holes.length} holes');

      if (holes.isEmpty) {
        throw Exception('No hole data available for this course');
      }

      int teeMarkersAdded = 0;
      int greenMarkersAdded = 0;
      int polygonsAdded = 0;

      // Add markers for all holes, organized by hole number
      for (var hole in holes) {
        print('\n--- Processing Hole ${hole.holeNumber} ---');
        print('Par: ${hole.par}, Handicap: ${hole.handicap}');
        print('Tee boxes available: ${hole.teeBoxes?.length ?? 0}');
        print('Green location: ${hole.greenLocation != null ? "Yes" : "No"}');

        final holeMarkers = <Marker>{};
        final holePolygons = <Polygon>{};

        // Add tee box markers for selected tee color
        if (hole.teeBoxes != null && hole.teeBoxes!.isNotEmpty) {
          // Try exact match first, then fuzzy match for shared tees
          final selectedTee = hole.teeBoxes!.firstWhere(
            (tee) => tee.tee.toLowerCase() == widget.teeColor.toLowerCase(),
            orElse: () {
              return hole.teeBoxes!.firstWhere(
                (tee) => tee.tee
                    .toLowerCase()
                    .split(';')
                    .map((c) => c.trim())
                    .contains(widget.teeColor.toLowerCase()),
                orElse: () => hole.teeBoxes!.first,
              );
            },
          );

          print(
              'Selected tee: ${selectedTee.tee}, Location: ${selectedTee.location?.latitude}, ${selectedTee.location?.longitude}');

          if (selectedTee.location?.latitude != null &&
              selectedTee.location?.longitude != null) {
            holeMarkers.add(
              Marker(
                markerId: MarkerId('tee_${hole.holeNumber}'),
                position: LatLng(
                  selectedTee.location!.latitude!,
                  selectedTee.location!.longitude!,
                ),
                infoWindow: InfoWindow(
                  title: 'Hole ${hole.holeNumber} Tee',
                  snippet: '${selectedTee.tee} • Par ${hole.par ?? "?"}',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ),
            );
            teeMarkersAdded++;
            print('✓ Added tee marker for hole ${hole.holeNumber}');
          } else {
            print('✗ No valid tee location for hole ${hole.holeNumber}');
          }
        } else {
          print('✗ No tee boxes for hole ${hole.holeNumber}');
        }

        // Add green marker
        if (hole.greenLocation?.latitude != null &&
            hole.greenLocation?.longitude != null) {
          holeMarkers.add(
            Marker(
              markerId: MarkerId('green_${hole.holeNumber}'),
              position: LatLng(
                hole.greenLocation!.latitude!,
                hole.greenLocation!.longitude!,
              ),
              infoWindow: InfoWindow(
                title: 'Hole ${hole.holeNumber} Green',
                snippet: 'Par ${hole.par ?? "?"}',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
          );
          greenMarkersAdded++;
          print('✓ Added green marker for hole ${hole.holeNumber}');
        } else {
          print('✗ No green location for hole ${hole.holeNumber}');
        }

        // Draw green polygon
        if (hole.greenCoordinates != null && hole.greenCoordinates!.isNotEmpty) {
          try {
            final validCoords = hole.greenCoordinates!
                .where((coord) => coord.latitude != null && coord.longitude != null)
                .map((coord) => LatLng(coord.latitude!, coord.longitude!))
                .toList();

            if (validCoords.length >= 3) {
              holePolygons.add(
                Polygon(
                  polygonId: PolygonId('green_polygon_${hole.holeNumber}'),
                  points: validCoords,
                  fillColor: Colors.green.withOpacity(0.3),
                  strokeColor: Colors.green,
                  strokeWidth: 2,
                ),
              );
              polygonsAdded++;
              print(
                  '✓ Added green polygon for hole ${hole.holeNumber} with ${validCoords.length} points');
            }
          } catch (e) {
            print('✗ Error creating polygon for hole ${hole.holeNumber}: $e');
          }
        }

        // Store markers and polygons for this hole
        _holeMarkers[hole.holeNumber] = holeMarkers;
        _holePolygons[hole.holeNumber] = holePolygons;
      }

      print('\n=== Summary ===');
      print('Total holes: ${holes.length}');
      print('Tee markers added: $teeMarkersAdded');
      print('Green markers added: $greenMarkersAdded');
      print('Green polygons added: $polygonsAdded');

      setState(() {
        _holes = holes;
        _isLoadingHoleData = false;
      });

      // Update distance and polyline after holes are loaded
      _updateDistanceToGreen();
      _updatePolylineToGreen();
      // After: _moveCameraToCurrentHole();
      if (Platform.isIOS && currentHole != null) {
        startLiveActivity(
          holeNumber: currentHole!.holeNumber,
          distanceToGreen: _distanceToGreen?.round() ?? 0,
          relativeToPar: _relativeToPar,
          courseName: widget.course.courseName,
        );
      }

      // Move camera to first hole after a short delay
      if (holes.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 800));
        print('\nMoving camera to first hole...');
        _moveCameraToCurrentHole();
      }
    } catch (e) {
      print('ERROR loading course data: $e');
      setState(() {
        _isLoadingHoleData = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading hole data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _moveCameraToCurrentHole() async {
    if (currentHole == null) {
      print('No current hole to move to');
      return;
    }

    print('Moving camera to hole ${currentHole!.holeNumber}');

    final teeBox = currentTeeBox;
    final green = currentHole!.greenLocation;

    // Check if we have valid tee location at minimum
    if (teeBox?.location?.latitude == null || teeBox?.location?.longitude == null) {
      print('Warning: Missing tee location for hole ${currentHole!.holeNumber}');
      // Try to use green location as fallback
      if (green?.latitude != null && green?.longitude != null) {
        try {
          await mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(green!.latitude!, green.longitude!),
                zoom: 17.8,
                tilt: 0,
              ),
            ),
          );
        } catch (e) {
          print('Error moving to green location: $e');
        }
      }
      return;
    }

    try {
      final teeLatLng = LatLng(
        teeBox!.location!.latitude!,
        teeBox.location!.longitude!,
      );

      print('Tee location: ${teeLatLng.latitude}, ${teeLatLng.longitude}');

      // If we have both tee and green, calculate bearing and show both
      if (green?.latitude != null && green?.longitude != null) {
        final greenLatLng = LatLng(green!.latitude!, green.longitude!);

        print('Green location: ${greenLatLng.latitude}, ${greenLatLng.longitude}');

        // Calculate bearing from tee to green
        final bearing = _calculateBearing(
          teeBox.location!.latitude!,
          teeBox.location!.longitude!,
          green.latitude!,
          green.longitude!,
        );

        print('Bearing to green: $bearing');

        // Calculate center point between tee and green
        final centerLat = (teeLatLng.latitude + greenLatLng.latitude) / 2;
        final centerLng = (teeLatLng.longitude + greenLatLng.longitude) / 2;
        final centerPoint = LatLng(centerLat, centerLng);

        // Animate to center point with bearing towards green
        await mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: centerPoint,
              zoom: 17.8,
              bearing: bearing,
              tilt: 45,
            ),
          ),
        );
      } else {
        // Just show tee box if no green location
        print('No green location, showing tee box only');
        await mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: teeLatLng,
              zoom: 17.8,
              tilt: 0,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error moving camera to hole: $e');
    }
  }

  double _calculateBearing(
      double startLat, double startLng, double endLat, double endLng) {
    final startLatRad = startLat * math.pi / 180;
    final startLngRad = startLng * math.pi / 180;
    final endLatRad = endLat * math.pi / 180;
    final endLngRad = endLng * math.pi / 180;

    final dLng = endLngRad - startLngRad;

    final y = math.sin(dLng) * math.cos(endLatRad);
    final x = math.cos(startLatRad) * math.sin(endLatRad) -
        math.sin(startLatRad) * math.cos(endLatRad) * math.cos(dLng);

    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  void _showScoreBottomSheet() {
    if (currentHole == null) return;

    final doublePar = (currentHole!.par ?? 4) * 2;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hole ${currentHole!.holeNumber}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Par ${currentHole!.par}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Score Selection
              const Text(
                'Score',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  doublePar,
                  (index) {
                    final score = index + 1;
                    final isSelected = _currentScore == score;
                    return _buildScoreChip(
                      score,
                      isSelected,
                      () {
                        setModalState(() {
                          _currentScore = score;
                        });
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Putts Selection
              const Text(
                'Putts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ...List.generate(4, (index) {
                    final putts = index;
                    final isSelected = _currentPutts == putts;
                    return _buildScoreChip(
                      putts,
                      isSelected,
                      () {
                        setModalState(() {
                          _currentPutts = putts;
                        });
                      },
                    );
                  }),
                  _buildScoreChip(
                    -1, // Special value for 4+
                    _currentPutts == 4,
                    () {
                      setModalState(() {
                        _currentPutts = 4;
                      });
                    },
                    label: '4+',
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Finish Hole Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _currentScore != null && _currentPutts != null
                      ? () {
                          Navigator.pop(context);
                          _finishHole();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B8E4E),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Finish Hole ${currentHole!.holeNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreChip(int value, bool isSelected, VoidCallback onTap,
      {String? label}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6B8E4E) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF6B8E4E) : Colors.grey[300]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label ?? value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF2D3E1F),
            ),
          ),
        ),
      ),
    );
  }

  void _finishHole() {
    // Save hole score
    _holeScores[currentHole!.holeNumber] = _currentScore!;
    print('Hole ${currentHole!.holeNumber}: Score=$_currentScore, Putts=$_currentPutts');

    // Move to next hole
    if (_currentHoleIndex < (_holes?.length ?? 0) - 1) {
      setState(() {
        _currentHoleIndex++;
        _currentScore = null;
        _currentPutts = null;
      });

      // Update distance and polyline for new hole
      _updateDistanceToGreen();
      _updatePolylineToGreen();
      _moveCameraToCurrentHole();

      // Update Live Activity for new hole
      _updateLiveActivity();
    } else {
      // Round complete - end Live Activity and navigate to end screen
      _endLiveActivity();
      _navigateToEndOfRound();
    }
  }

  void _navigateToEndOfRound() {
    if (_holes == null || _holes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No hole data available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    context.pushReplacement(
      '/end-of-round',
      extra: {
        'course': widget.course,
        'teeColor': widget.teeColor,
        'holes': _holes!,
        'holeScores': _holeScores,
      },
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingHoleData) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.course.courseName),
          backgroundColor: const Color(0xFF6B8E4E),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF6B8E4E)),
              SizedBox(height: 16),
              Text('Loading course details...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            mapType: MapType.satellite,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.course.location.latitude!,
                widget.course.location.longitude!,
              ),
              zoom: 16.0,
            ),
            markers: _currentMarkers,
            polygons: _currentPolygons,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Hole Info Header with Back Button
          if (currentHole != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  // Back Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Hole Info
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF6B8E4E),
                                radius: 16,
                                child: Text(
                                  '#${currentHole!.holeNumber}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Par ${currentHole!.par ?? "?"}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${widget.teeColor} ${currentTeeBox?.yards?.toString() ?? "?"} yds',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            'HCP ${currentHole!.handicap?.toString() ?? "?"}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Distance to Green Indicator (below floating button)
          if (_distanceToGreen != null && currentHole != null)
            Positioned(
              bottom: 100, // Position above the floating button
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade700,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Live indicator (pulsing dot)
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(_pulseAnimation.value),
                                  blurRadius: 4 * _pulseAnimation.value,
                                  spreadRadius: 2 * _pulseAnimation.value,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(width: 12),
                      const SizedBox(width: 6),
                      Text(
                        '${_distanceToGreen!.round()} yds',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Live Score Indicator (Bottom Right, more compact design)
          if (_holeScores.isNotEmpty)
            Positioned(
              bottom: 32,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _relativeToPar == 0
                          ? 'E'
                          : '${_relativeToPar > 0 ? '+' : ''}$_relativeToPar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _relativeToPar > 0
                            ? Colors.red
                            : _relativeToPar < 0
                                ? Colors.green
                                : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 1,
                      height: 20,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'T${_holeScores.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Floating Hole Button (centered at bottom)
          if (currentHole != null)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton.extended(
                  onPressed: _showScoreBottomSheet,
                  backgroundColor: const Color(0xFF6B8E4E),
                  icon: const Icon(Icons.golf_course, color: Colors.white),
                  label: Text(
                    'Hole ${currentHole!.holeNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
