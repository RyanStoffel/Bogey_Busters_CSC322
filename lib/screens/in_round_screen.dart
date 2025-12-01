import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/models/models.dart';
import 'package:golf_tracker_app/services/overpass_api_service.dart';
import 'package:golf_tracker_app/services/round_persistence_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:live_activities/live_activities.dart';

class InRoundScreen extends StatefulWidget {
  final Course? course;
  final String? teeColor;
  final bool isResumingRound; // New parameter to indicate if resuming

  const InRoundScreen({
    super.key,
    required this.course,
    required this.teeColor,
    this.isResumingRound = false,
  });

  @override
  State<InRoundScreen> createState() => _InRoundScreenState();
}

class _InRoundScreenState extends State<InRoundScreen>
    with SingleTickerProviderStateMixin {
  late GoogleMapController mapController;
  final OverpassApiService _overpassApiService = OverpassApiService();
  final _liveActivitiesPlugin = LiveActivities();
  final RoundPersistenceService _persistenceService = RoundPersistenceService();
  String? _activityId;

  // Store course and teeColor when loaded from saved state
  Course? _course;
  String? _teeColor;

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

  // Getters that return either widget values or loaded values
  Course? get course => widget.course ?? _course;
  String? get teeColor => widget.teeColor ?? _teeColor;

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
    if (_activityId != null && currentHole != null && course != null) {
      updateLiveActivity(
        holeNumber: currentHole!.holeNumber,
        distanceToGreen: _distanceToGreen?.round() ?? 0,
        relativeToPar: _relativeToPar,
        courseName: course!.courseName,
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

  // NEW: Save round state whenever it changes
  Future<void> _saveRoundState() async {
    if (_holes == null || _holes!.isEmpty || course == null || teeColor == null) return;

    await _persistenceService.saveRoundState(
      course: course!,
      teeColor: teeColor!,
      holes: _holes!,
      holeScores: _holeScores,
      currentHoleIndex: _currentHoleIndex,
    );
  }

  // NEW: Try to load saved round state
  Future<bool> _tryLoadSavedRound() async {
    if (!widget.isResumingRound) return false;

    final savedState = await _persistenceService.loadRoundState();
    if (savedState == null) return false;

    setState(() {
      _holes = savedState['holes'] as List<Hole>;
      _holeScores = savedState['holeScores'] as Map<int, int>;
      _currentHoleIndex = savedState['currentHoleIndex'] as int;
    });

    print('✅ Resumed round at hole ${_currentHoleIndex + 1}');
    return true;
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

    // Start live activity after data is loaded
    // Wait longer to ensure course data is loaded from saved state
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (currentHole != null && course != null) {
        try {
          startLiveActivity(
            holeNumber: currentHole!.holeNumber,
            distanceToGreen: _distanceToGreen?.round() ?? 0,
            relativeToPar: _relativeToPar,
            courseName: course!.courseName,
          );
        } catch (e) {
          print('⚠️ Live Activity error (safe to ignore): $e');
          // Live Activities might not be initialized - that's okay
        }
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
    if (currentHole?.teeBoxes == null || teeColor == null) return null;

    // Try to find exact match first
    var teeBox = currentHole!.teeBoxes!.firstWhere(
      (tee) => tee.tee.toLowerCase() == teeColor!.toLowerCase(),
      orElse: () {
        // Try to find a shared tee that contains this color
        return currentHole!.teeBoxes!.firstWhere(
          (tee) => tee.tee
              .toLowerCase()
              .split(';')
              .map((c) => c.trim())
              .contains(teeColor!.toLowerCase()),
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

    // NEW: If course is null, we MUST load from saved state
    if (widget.course == null || widget.teeColor == null) {
      final savedState = await _persistenceService.loadRoundState();
      if (savedState == null) {
        // This shouldn't happen, but handle it gracefully
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active round found')),
          );
          context.go('/courses');
        }
        return;
      }
      
      // Load the course and teeColor from saved state and store in state variables
      setState(() {
        _course = savedState['course'] as Course;
        _teeColor = savedState['teeColor'] as String;
        _holes = savedState['holes'] as List<Hole>;
        _holeScores = savedState['holeScores'] as Map<int, int>;
        _currentHoleIndex = savedState['currentHoleIndex'] as int;
        _isLoadingHoleData = false;
      });
      
      _updateDistanceToGreen();
      _updatePolylineToGreen();
      _moveCameraToCurrentHole();
      print('✅ Resumed round from automatic redirect at hole ${_currentHoleIndex + 1}');
      return;
    }

    // NEW: Try to load saved round first (when explicitly resuming)
    final resumedFromSave = await _tryLoadSavedRound();
    
    if (resumedFromSave) {
      // If we resumed from save, we still need to fetch course details for markers
      // but we don't need to reset the state
      setState(() {
        _isLoadingHoleData = false;
      });
      _updateDistanceToGreen();
      _updatePolylineToGreen();
      _moveCameraToCurrentHole();
      return;
    }

    try {
      print('Fetching course details for ${course!.courseId}');
      final courseDetails = await _overpassApiService.fetchCourseDetails(
        course!.courseId,
      );

      final holes = courseDetails.holes ?? [];
      print('Found ${holes.length} holes');

      if (holes.isEmpty) {
        throw Exception('No hole data available for this course');
      }

      // Add markers for all holes, organized by hole number
      for (var hole in holes) {
        final holeMarkers = <Marker>{};
        final holePolygons = <Polygon>{};

        // Add tee box markers for selected tee color
        if (hole.teeBoxes != null && hole.teeBoxes!.isNotEmpty) {
          // Try exact match first, then fuzzy match for shared tees
          final selectedTee = hole.teeBoxes!.firstWhere(
            (tee) => tee.tee.toLowerCase() == teeColor!.toLowerCase(),
            orElse: () {
              return hole.teeBoxes!.firstWhere(
                (tee) => tee.tee
                    .toLowerCase()
                    .split(';')
                    .map((c) => c.trim())
                    .contains(teeColor!.toLowerCase()),
                orElse: () => hole.teeBoxes!.first,
              );
            },
          );

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
          }
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
            }
          } catch (e) {
            print('✗ Error creating polygon for hole ${hole.holeNumber}: $e');
          }
        }

        // Store markers and polygons for this hole
        _holeMarkers[hole.holeNumber] = holeMarkers;
        _holePolygons[hole.holeNumber] = holePolygons;
      }

      setState(() {
        _holes = holes;
        _isLoadingHoleData = false;
      });

      // NEW: Save initial round state
      await _saveRoundState();

      // Update distance and polyline after holes are loaded
      _updateDistanceToGreen();
      _updatePolylineToGreen();
      
      if (Platform.isIOS && currentHole != null) {
        startLiveActivity(
          holeNumber: currentHole!.holeNumber,
          distanceToGreen: _distanceToGreen?.round() ?? 0,
          relativeToPar: _relativeToPar,
          courseName: course!.courseName,
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
        return;
      }
      
      // Last resort: use course center if available
      if (course?.location.latitude != null && course?.location.longitude != null) {
        print('Using course center as fallback');
        try {
          await mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(course!.location.latitude!, course!.location.longitude!),
                zoom: 16.0,
                tilt: 0,
              ),
            ),
          );
        } catch (e) {
          print('Error moving to course center: $e');
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
    final bool isHoleCompleted = _holeScores.containsKey(currentHole!.holeNumber);
    
    // If editing existing score, load it
    if (isHoleCompleted && _currentScore == null) {
      _currentScore = _holeScores[currentHole!.holeNumber];
    }

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
                    onPressed: () {
                      // Reset score if cancelling
                      if (!isHoleCompleted) {
                        _currentScore = null;
                        _currentPutts = null;
                      }
                      Navigator.pop(context);
                    },
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
                    isHoleCompleted 
                        ? 'Update Hole ${currentHole!.holeNumber}'
                        : 'Finish Hole ${currentHole!.holeNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              // Finish Round Early button (only show if at least one hole completed)
              if (_holeScores.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showFinishRoundEarlyDialog();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Finish Round Early',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
              
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Show finish round early confirmation
  Future<void> _showFinishRoundEarlyDialog() async {
    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final completedHoles = _holeScores.length;
        final totalHoles = _holes?.length ?? 18;
        
        return AlertDialog(
          title: const Text('Finish Round Early?'),
          content: Text(
            'You\'ve completed $completedHoles of $totalHoles holes.\n\n'
            'Do you want to finish the round now? Your score will be recorded for the holes you\'ve completed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Continue Playing'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Finish Round'),
            ),
          ],
        );
      },
    );

    if (shouldFinish == true) {
      _endLiveActivity();
      await _persistenceService.clearRoundState();
      _navigateToEndOfRound();
    }
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

  void _finishHole() async { // Made async
    // Save hole score
    _holeScores[currentHole!.holeNumber] = _currentScore!;
    print('Hole ${currentHole!.holeNumber}: Score=$_currentScore, Putts=$_currentPutts');

    // NEW: Save round state after finishing a hole
    await _saveRoundState();

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
      // NEW: Clear saved round state when completing
      await _persistenceService.clearRoundState();
      _navigateToEndOfRound();
    }
  }

  void _navigateToEndOfRound() {
    if (_holes == null || _holes!.isEmpty || course == null || teeColor == null) {
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
        'course': course!,
        'teeColor': teeColor!,
        'holes': _holes!,
        'holeScores': _holeScores,
      },
    );
  }

  // NEW: Show cancel round confirmation
  Future<bool> _showCancelRoundDialog() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Round?'),
          content: const Text(
            'Are you sure you want to cancel this round? Your progress will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Continue Round'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Cancel Round'),
            ),
          ],
        );
      },
    );

    if (shouldCancel == true) {
      await _persistenceService.clearRoundState();
      _endLiveActivity();
      return true;
    }

    return false;
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingHoleData) {
      return Scaffold(
        appBar: AppBar(
          title: Text(course?.courseName ?? 'Loading...'),
          backgroundColor: const Color(0xFF6B8E4E),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldCancel = await _showCancelRoundDialog();
              if (shouldCancel && context.mounted) {
                context.go('/courses');
              }
            },
          ),
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

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final shouldExit = await _showCancelRoundDialog();
        if (shouldExit && context.mounted) {
          context.go('/courses');
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Map
            GoogleMap(
              onMapCreated: _onMapCreated,
              mapType: MapType.satellite,
              initialCameraPosition: CameraPosition(
                target: course?.location.latitude != null && course?.location.longitude != null
                    ? LatLng(
                        course!.location.latitude!,
                        course!.location.longitude!,
                      )
                    : currentHole?.greenLocation?.latitude != null && currentHole?.greenLocation?.longitude != null
                        ? LatLng(
                            currentHole!.greenLocation!.latitude!,
                            currentHole!.greenLocation!.longitude!,
                          )
                        : const LatLng(0, 0), // Fallback to 0,0 if nothing available
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
                    // Back Button - now shows cancel dialog
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
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () async {
                          final shouldCancel = await _showCancelRoundDialog();
                          if (shouldCancel && context.mounted) {
                            context.go('/courses');
                          }
                        },
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Hole Info with Navigation
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
                            // Previous Hole Button
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 24),
                              onPressed: _currentHoleIndex > 0
                                  ? () {
                                      setState(() {
                                        _currentHoleIndex--;
                                        _currentScore = _holeScores[currentHole!.holeNumber];
                                        _currentPutts = null; // We don't save putts
                                      });
                                      _updateDistanceToGreen();
                                      _updatePolylineToGreen();
                                      _moveCameraToCurrentHole();
                                      _updateLiveActivity();
                                    }
                                  : null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: _currentHoleIndex > 0 ? const Color(0xFF6B8E4E) : Colors.grey[300],
                            ),
                            const SizedBox(width: 8),
                            // Hole Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: const Color(0xFF6B8E4E),
                                        radius: 12,
                                        child: Text(
                                          '${currentHole!.holeNumber}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Par ${currentHole!.par ?? "?"}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${teeColor ?? "?"} ${currentTeeBox?.yards?.toString() ?? "?"} yds • HCP ${currentHole!.handicap?.toString() ?? "?"}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Next Hole Button
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 24),
                              onPressed: _currentHoleIndex < (_holes?.length ?? 0) - 1
                                  ? () {
                                      setState(() {
                                        _currentHoleIndex++;
                                        _currentScore = _holeScores[currentHole!.holeNumber];
                                        _currentPutts = null;
                                      });
                                      _updateDistanceToGreen();
                                      _updatePolylineToGreen();
                                      _moveCameraToCurrentHole();
                                      _updateLiveActivity();
                                    }
                                  : null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: _currentHoleIndex < (_holes?.length ?? 0) - 1
                                  ? const Color(0xFF6B8E4E)
                                  : Colors.grey[300],
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
                      _holeScores.containsKey(currentHole!.holeNumber)
                          ? 'Edit Hole ${currentHole!.holeNumber}'
                          : 'Hole ${currentHole!.holeNumber}',
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
      ),
    );
  }
}