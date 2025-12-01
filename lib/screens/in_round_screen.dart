import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/models/models.dart';
import 'package:golf_tracker_app/services/firestore_service.dart';
import 'package:golf_tracker_app/services/overpass_api_service.dart';
import 'package:golf_tracker_app/services/round_persistence_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class InRoundScreen extends StatefulWidget {
  final Course? course;
  final String? teeColor;
  final bool isResumingRound;

  const InRoundScreen({
    super.key,
    required this.course,
    required this.teeColor,
    this.isResumingRound = false,
  });

  @override
  State<InRoundScreen> createState() => _InRoundScreenState();
}

class _InRoundScreenState extends State<InRoundScreen> {
  late GoogleMapController mapController;
  final FirestoreService _firestoreService = FirestoreService();
  final OverpassApiService _overpassApiService = OverpassApiService();
  final RoundPersistenceService _persistenceService = RoundPersistenceService();

  Course? _course;
  String? _teeColor;

  final Map<int, Set<Marker>> _holeMarkers = {};
  final Map<int, Set<Polygon>> _holePolygons = {};

  bool _isLoadingHoleData = true;
  List<Hole>? _holes;
  int _currentHoleIndex = 0;

  int? _currentScore;
  int? _currentPutts;
  Map<int, int> _holeScores = {};

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  Set<Polyline> _polylines = {};
  double? _distanceToGreen;

  LatLng? _markerPosition;
  double? _markerDistanceToGreen;
  double? _markerDistanceToTee;

  BitmapDescriptor? _userLocationIcon;

  BitmapDescriptor? _teeToMarkerLabelIcon;
  BitmapDescriptor? _markerToGreenLabelIcon;
  LatLng? _teeToMarkerMidpoint;
  LatLng? _markerToGreenMidpoint;

  bool _isHeaderExpanded = false;

  Course? get course => widget.course ?? _course;
  String? get teeColor => widget.teeColor ?? _teeColor;

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

  Future<bool> _tryLoadSavedRound() async {
    if (!widget.isResumingRound) return false;

    final savedState = await _persistenceService.loadRoundState();
    if (savedState == null) return false;

    setState(() {
      _holes = savedState['holes'] as List<Hole>;
      _holeScores = savedState['holeScores'] as Map<int, int>;
      _currentHoleIndex = savedState['currentHoleIndex'] as int;
    });

    return true;
  }

  @override
  void initState() {
    super.initState();

    _createCustomMarkers();
    _loadCourseData();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _createCustomMarkers() async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..isAntiAlias = true;

    const size = 56.0;
    const center = size / 2;
    const circleRadius = size / 2 - 8;
    const lineGap = 8.0;
    const centerDotRadius = 3.0;

    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawCircle(
      const Offset(center, center),
      circleRadius,
      paint,
    );

    paint.strokeCap = StrokeCap.round;

    canvas.drawLine(
      const Offset(center, 0),
      const Offset(center, center - lineGap),
      paint,
    );

    canvas.drawLine(
      const Offset(center, size),
      const Offset(center, center + lineGap),
      paint,
    );

    canvas.drawLine(
      const Offset(0, center),
      const Offset(center - lineGap, center),
      paint,
    );

    canvas.drawLine(
      const Offset(size, center),
      const Offset(center + lineGap, center),
      paint,
    );

    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
      const Offset(center, center),
      centerDotRadius,
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

  Future<BitmapDescriptor> _createDistanceLabel(String distanceText) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..isAntiAlias = true;

    const scale = 3.0;

    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 8 * scale,
      fontWeight: FontWeight.bold,
    );
    final textSpan = TextSpan(text: distanceText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    const padding = 3.0 * scale;
    final boxWidth = textPainter.width + (padding * 2);
    final boxHeight = textPainter.height + (padding * 2);

    paint.color = Colors.black.withOpacity(0.85);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, boxWidth, boxHeight),
      Radius.circular(6 * scale),
    );
    canvas.drawRRect(rect, paint);

    textPainter.paint(
      canvas,
      Offset(padding, padding),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(boxWidth.toInt(), boxHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(buffer);
  }

  void _startLocationTracking() async {
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
      }
    } catch (e) {
      print('Error getting initial position: $e');
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        _updateDistanceToGreen();
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
    }
  }


  void _onMapTapped(LatLng position) {
    setState(() {
      _markerPosition = position;
    });
    _updateMarkerDistances();
  }

  void _setMarkerToHoleCenter() {
    if (currentHole == null) return;

    final teeBox = currentTeeBox;
    final green = currentHole!.greenLocation;

    if (teeBox?.location?.latitude == null || teeBox?.location?.longitude == null ||
        green?.latitude == null || green?.longitude == null) {
      return;
    }

    final centerLat = (teeBox!.location!.latitude! + green!.latitude!) / 2;
    final centerLng = (teeBox.location!.longitude! + green.longitude!) / 2;

    setState(() {
      _markerPosition = LatLng(centerLat, centerLng);
    });

    _updateMarkerDistances();
  }

  void _updateMarkerDistances() async {
    if (_markerPosition == null || currentHole == null) {
      if (mounted) {
        setState(() {
          _markerDistanceToGreen = null;
          _markerDistanceToTee = null;
          _polylines.clear();
          _teeToMarkerLabelIcon = null;
          _markerToGreenLabelIcon = null;
          _teeToMarkerMidpoint = null;
          _markerToGreenMidpoint = null;
        });
      }
      return;
    }

    final green = currentHole!.greenLocation;
    final teeBox = currentTeeBox;

    if (green?.latitude != null && green?.longitude != null) {
      final distanceToGreenInMeters = Geolocator.distanceBetween(
        _markerPosition!.latitude,
        _markerPosition!.longitude,
        green!.latitude!,
        green.longitude!,
      );
      _markerDistanceToGreen = distanceToGreenInMeters * 1.09361;
    }

    if (teeBox?.location?.latitude != null && teeBox?.location?.longitude != null) {
      final distanceToTeeInMeters = Geolocator.distanceBetween(
        _markerPosition!.latitude,
        _markerPosition!.longitude,
        teeBox!.location!.latitude!,
        teeBox.location!.longitude!,
      );
      _markerDistanceToTee = distanceToTeeInMeters * 1.09361;
    }

    final polylines = <Polyline>{};
    const double circleRadiusMeters = 2.5;

    if (teeBox?.location?.latitude != null && teeBox?.location?.longitude != null && _markerDistanceToTee != null) {
      final teeLatLng = LatLng(teeBox!.location!.latitude!, teeBox.location!.longitude!);

      final bearing = _calculateBearing(
        teeLatLng.latitude,
        teeLatLng.longitude,
        _markerPosition!.latitude,
        _markerPosition!.longitude,
      );

      final circleEdgePoint = _calculatePointAtDistance(
        _markerPosition!.latitude,
        _markerPosition!.longitude,
        bearing,
        circleRadiusMeters,
      );

      polylines.add(
        Polyline(
          polylineId: const PolylineId('tee_to_marker'),
          points: [
            teeLatLng,
            circleEdgePoint,
          ],
          color: Colors.white,
          width: 3,
        ),
      );

      _teeToMarkerMidpoint = LatLng(
        (teeLatLng.latitude + _markerPosition!.latitude) / 2,
        (teeLatLng.longitude + _markerPosition!.longitude) / 2,
      );

      _teeToMarkerLabelIcon = await _createDistanceLabel('${_markerDistanceToTee!.round()} yds');
    }

    if (green?.latitude != null && green?.longitude != null && _markerDistanceToGreen != null) {
      final greenLatLng = LatLng(green!.latitude!, green.longitude!);

      final bearing = _calculateBearing(
        greenLatLng.latitude,
        greenLatLng.longitude,
        _markerPosition!.latitude,
        _markerPosition!.longitude,
      );

      final circleEdgePoint = _calculatePointAtDistance(
        _markerPosition!.latitude,
        _markerPosition!.longitude,
        bearing,
        circleRadiusMeters,
      );

      polylines.add(
        Polyline(
          polylineId: const PolylineId('marker_to_green'),
          points: [
            circleEdgePoint,
            greenLatLng,
          ],
          color: Colors.white,
          width: 3,
        ),
      );

      _markerToGreenMidpoint = LatLng(
        (_markerPosition!.latitude + greenLatLng.latitude) / 2,
        (_markerPosition!.longitude + greenLatLng.longitude) / 2,
      );

      _markerToGreenLabelIcon = await _createDistanceLabel('${_markerDistanceToGreen!.round()} yds');
    }

    if (mounted) {
      setState(() {
        _polylines = polylines;
      });
    }
  }

  Set<Marker> get _currentMarkers {
    final currentHoleNum = currentHole?.holeNumber;
    if (currentHoleNum == null) return {};

    final markers = Set<Marker>.from(_holeMarkers[currentHoleNum] ?? {});

    if (_markerPosition != null && _userLocationIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _markerPosition!,
          icon: _userLocationIcon!,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    if (_teeToMarkerMidpoint != null && _teeToMarkerLabelIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('tee_to_marker_label'),
          position: _teeToMarkerMidpoint!,
          icon: _teeToMarkerLabelIcon!,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    if (_markerToGreenMidpoint != null && _markerToGreenLabelIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('marker_to_green_label'),
          position: _markerToGreenMidpoint!,
          icon: _markerToGreenLabelIcon!,
          anchor: const Offset(0.5, 0.5),
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

    var teeBox = currentHole!.teeBoxes!.firstWhere(
      (tee) => tee.tee.toLowerCase() == teeColor!.toLowerCase(),
      orElse: () {
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

    if (widget.course == null || widget.teeColor == null) {
      final savedState = await _persistenceService.loadRoundState();
      if (savedState == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active round found')),
          );
          context.go('/courses');
        }
        return;
      }

      setState(() {
        _course = savedState['course'] as Course;
        _teeColor = savedState['teeColor'] as String;
        _holes = savedState['holes'] as List<Hole>;
        _holeScores = savedState['holeScores'] as Map<int, int>;
        _currentHoleIndex = savedState['currentHoleIndex'] as int;
        _isLoadingHoleData = false;
      });

      _updateDistanceToGreen();
      _setMarkerToHoleCenter();
      _moveCameraToCurrentHole();
      return;
    }

    final resumedFromSave = await _tryLoadSavedRound();

    if (resumedFromSave) {
      setState(() {
        _isLoadingHoleData = false;
      });
      _updateDistanceToGreen();
      _setMarkerToHoleCenter();
      _moveCameraToCurrentHole();
      return;
    }

    try {
      Course? courseDetails = await _firestoreService.getCachedCourse(course!.courseId);

      if (courseDetails == null || courseDetails.holes == null || courseDetails.holes!.isEmpty) {
        courseDetails = await _overpassApiService.fetchCourseDetails(course!.courseId);

        _firestoreService.cacheCourse(courseDetails).catchError((e) {
          print('Failed to cache course: $e');
        });
      }

      final holes = courseDetails.holes ?? [];

      if (holes.isEmpty) {
        throw Exception('No hole data available for this course');
      }

      for (var hole in holes) {
        final holeMarkers = <Marker>{};
        final holePolygons = <Polygon>{};

        if (hole.teeBoxes != null && hole.teeBoxes!.isNotEmpty) {
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
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ),
            );
          }
        }

        if (hole.greenLocation?.latitude != null &&
            hole.greenLocation?.longitude != null) {
          holeMarkers.add(
            Marker(
              markerId: MarkerId('green_${hole.holeNumber}'),
              position: LatLng(
                hole.greenLocation!.latitude!,
                hole.greenLocation!.longitude!,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
          );
        }

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
            print('Error creating polygon for hole ${hole.holeNumber}: $e');
          }
        }

        _holeMarkers[hole.holeNumber] = holeMarkers;
        _holePolygons[hole.holeNumber] = holePolygons;
      }

      setState(() {
        _holes = holes;
        _isLoadingHoleData = false;
      });

      await _saveRoundState();

      _updateDistanceToGreen();
      _setMarkerToHoleCenter();

      if (holes.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 800));
        _moveCameraToCurrentHole();
      }
    } catch (e) {
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
    if (currentHole == null) return;

    final teeBox = currentTeeBox;
    final green = currentHole!.greenLocation;

    if (teeBox?.location?.latitude == null || teeBox?.location?.longitude == null) {
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

      if (course?.location.latitude != null && course?.location.longitude != null) {
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

      if (green?.latitude != null && green?.longitude != null) {
        final greenLatLng = LatLng(green!.latitude!, green.longitude!);

        final bearing = _calculateBearing(
          teeBox.location!.latitude!,
          teeBox.location!.longitude!,
          green.latitude!,
          green.longitude!,
        );

        final centerLat = (teeLatLng.latitude + greenLatLng.latitude) / 2;
        final centerLng = (teeLatLng.longitude + greenLatLng.longitude) / 2;
        final centerPoint = LatLng(centerLat, centerLng);

        await mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: centerPoint,
              zoom: 17.4,
              bearing: bearing,
              tilt: 0,
            ),
          ),
        );
      } else {
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

  LatLng _calculatePointAtDistance(
      double lat, double lng, double bearing, double distanceMeters) {
    const double earthRadius = 6378137.0;
    final double angularDistance = distanceMeters / earthRadius;
    final double bearingRad = bearing * math.pi / 180;
    final double latRad = lat * math.pi / 180;
    final double lngRad = lng * math.pi / 180;

    final double newLatRad = math.asin(
        math.sin(latRad) * math.cos(angularDistance) +
        math.cos(latRad) * math.sin(angularDistance) * math.cos(bearingRad));

    final double newLngRad = lngRad +
        math.atan2(
            math.sin(bearingRad) * math.sin(angularDistance) * math.cos(latRad),
            math.cos(angularDistance) - math.sin(latRad) * math.sin(newLatRad));

    return LatLng(newLatRad * 180 / math.pi, newLngRad * 180 / math.pi);
  }

  void _showScoreBottomSheet() {
    if (currentHole == null) return;

    final doublePar = (currentHole!.par ?? 4) * 2;
    final bool isHoleCompleted = _holeScores.containsKey(currentHole!.holeNumber);

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
                    -1,
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

  void _finishHole() async {
    _holeScores[currentHole!.holeNumber] = _currentScore!;

    await _saveRoundState();

    if (_currentHoleIndex < (_holes?.length ?? 0) - 1) {
      setState(() {
        _currentHoleIndex++;
        _currentScore = null;
        _currentPutts = null;
      });

      _updateDistanceToGreen();
      _setMarkerToHoleCenter();
      _moveCameraToCurrentHole();
    } else {
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
              child: const Text('Continue Round', style: TextStyle(color: Colors.green),),
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
            GoogleMap(
              onMapCreated: _onMapCreated,
              onTap: _onMapTapped,
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
                        : const LatLng(0, 0),
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

            if (currentHole != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF4C4E52).withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 30, color: Colors.white),
                        onPressed: () async {
                          final shouldCancel = await _showCancelRoundDialog();
                          if (shouldCancel && context.mounted) {
                            context.go('/courses');
                          }
                        },
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4C4E52),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${currentHole!.holeNumber}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Mid Green',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      _distanceToGreen != null
                                          ? '${_distanceToGreen!.round()} yds'
                                          : 'Calc...',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isHeaderExpanded = !_isHeaderExpanded;
                                    });
                                  },
                                  child: Icon(
                                    _isHeaderExpanded
                                        ? Icons.chevron_left
                                        : Icons.chevron_right,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isHeaderExpanded)
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4C4E52).withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Par',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          '${currentHole!.par ?? "?"}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          teeColor ?? '?',
                                          style: const TextStyle(
                                            fontSize: 8,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          '${currentTeeBox?.yards ?? "?"} yds',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'HCP',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          '${currentHole!.handicap ?? "?"}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

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

            if (currentHole != null)
              Positioned(
                bottom: 32,
                left: 48,
                right: 48,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                   child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_currentHoleIndex > 0)
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0x4C4E52).withOpacity(0.9),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                bottomLeft: Radius.circular(24),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _currentHoleIndex--;
                                    _currentScore = _holeScores[currentHole!.holeNumber];
                                    _currentPutts = null;
                                  });
                                  _updateDistanceToGreen();
                                  _setMarkerToHoleCenter();
                                  _moveCameraToCurrentHole();
                                },
                                child: const Center(
                                  child: Icon(
                                    Icons.chevron_left,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Material(
                          color: const Color(0xFF6B8E4E),
                          borderRadius: BorderRadius.horizontal(
                            left: _currentHoleIndex == 0
                                ? const Radius.circular(12)
                                : Radius.zero,
                            right: _currentHoleIndex == (_holes?.length ?? 0) - 1
                                ? const Radius.circular(12)
                                : Radius.zero,
                          ),
                          child: InkWell(
                            onTap: _showScoreBottomSheet,
                            child: Container(
                              width: 160,
                              height: 64,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _holeScores.containsKey(currentHole!.holeNumber)
                                        ? 'Edit Hole ${currentHole!.holeNumber}'
                                        : 'Hole ${currentHole!.holeNumber}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Enter Score',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_currentHoleIndex < (_holes?.length ?? 0) - 1)
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0x4C4E52).withOpacity(0.9),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(24),
                                bottomRight: Radius.circular(24),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _currentHoleIndex++;
                                    _currentScore = _holeScores[currentHole!.holeNumber];
                                    _currentPutts = null;
                                  });
                                  _updateDistanceToGreen();
                                  _setMarkerToHoleCenter();
                                  _moveCameraToCurrentHole();
                                },
                                child: const Center(
                                  child: Icon(
                                    Icons.chevron_right,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
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