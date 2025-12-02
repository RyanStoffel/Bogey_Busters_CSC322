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
  int? _currentChipShots;
  int? _currentPenalties;
  bool? _currentGreenInRegulation;
  bool? _currentFairwayHit;
  bool _isCustomScoreMode = false;
  final TextEditingController _customScoreController = TextEditingController();
  Map<int, int> _holeScores = {};
  Map<int, int> _holePutts = {};
  Map<int, int> _holeChipShots = {};
  Map<int, int> _holePenalties = {};
  Map<int, bool> _holeGreenInRegulation = {};
  Map<int, bool> _holeFairwayHit = {};

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

  void _regenerateMarkersAndPolygons() {
    if (_holes == null || teeColor == null) return;

    _holeMarkers.clear();
    _holePolygons.clear();

    for (var hole in _holes!) {
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
  }

  Future<void> _saveRoundState() async {
    if (_holes == null || _holes!.isEmpty || course == null || teeColor == null) return;

    await _persistenceService.saveRoundState(
      course: course!,
      teeColor: teeColor!,
      holes: _holes!,
      holeScores: _holeScores,
      holePutts: _holePutts,
      holeChipShots: _holeChipShots,
      holePenalties: _holePenalties,
      holeGreenInRegulation: _holeGreenInRegulation,
      holeFairwayHit: _holeFairwayHit,
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
      _holePutts = savedState['holePutts'] as Map<int, int>? ?? {};
      _holeChipShots = savedState['holeChipShots'] as Map<int, int>? ?? {};
      _holePenalties = savedState['holePenalties'] as Map<int, int>? ?? {};
      _holeGreenInRegulation = savedState['holeGreenInRegulation'] as Map<int, bool>? ?? {};
      _holeFairwayHit = savedState['holeFairwayHit'] as Map<int, bool>? ?? {};
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
    _customScoreController.dispose();
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
        _holePutts = savedState['holePutts'] as Map<int, int>? ?? {};
        _holeChipShots = savedState['holeChipShots'] as Map<int, int>? ?? {};
        _holePenalties = savedState['holePenalties'] as Map<int, int>? ?? {};
        _holeGreenInRegulation = savedState['holeGreenInRegulation'] as Map<int, bool>? ?? {};
        _holeFairwayHit = savedState['holeFairwayHit'] as Map<int, bool>? ?? {};
        _currentHoleIndex = savedState['currentHoleIndex'] as int;
        _isLoadingHoleData = false;
      });

      // Regenerate markers and polygons for all holes
      _regenerateMarkersAndPolygons();

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

  void _showScorecardModal() {
    if (_holes == null || _holes!.isEmpty) return;

    // Calculate stats
    int totalPutts = 0;
    int totalGIR = 0;
    int totalFairways = 0;
    int totalChips = 0;
    int totalPenalties = 0;

    _holePutts.forEach((_, putts) => totalPutts += putts);
    _holeGreenInRegulation.forEach((_, gir) { if (gir) totalGIR++; });
    _holeFairwayHit.forEach((_, hit) { if (hit) totalFairways++; });
    _holeChipShots.forEach((_, chips) => totalChips += chips);
    _holePenalties.forEach((_, penalties) => totalPenalties += penalties);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Fixed Header
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5E7A45), Color(0xFF6B8E4E)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Title Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 12, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Scorecard',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(context),
                            padding: const EdgeInsets.all(8),
                          ),
                        ],
                      ),
                    ),

                    // Main Stats
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildMainStatCard(
                              'Total Score',
                              '$totalScore',
                              Icons.sports_golf_rounded,
                              Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMainStatCard(
                              'To Par',
                              _relativeToPar == 0
                                  ? 'Even'
                                  : '${_relativeToPar > 0 ? '+' : ''}$_relativeToPar',
                              _relativeToPar > 0
                                  ? Icons.trending_up_rounded
                                  : _relativeToPar < 0
                                      ? Icons.trending_down_rounded
                                      : Icons.trending_flat_rounded,
                              _relativeToPar > 0
                                  ? const Color(0xFFFFE5E5)
                                  : _relativeToPar < 0
                                      ? const Color(0xFFE5F5E5)
                                      : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMainStatCard(
                              'Putts',
                              '$totalPutts',
                              Icons.flag_rounded,
                              Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Secondary Stats
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSecondaryStatItem(
                            'GIR',
                            '$totalGIR/${_holeGreenInRegulation.length}',
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildSecondaryStatItem(
                            'Fairways',
                            '$totalFairways/${_holeFairwayHit.length}',
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildSecondaryStatItem(
                            'Chips',
                            '$totalChips',
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildSecondaryStatItem(
                            'Penalties',
                            '$totalPenalties',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Scrollable Table
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      // Table Header (sticky)
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D3E1F),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            child: Row(
                              children: [
                                _buildTableHeaderCell('Hole', 50),
                                _buildTableHeaderCell('Par', 45),
                                _buildTableHeaderCell('Score', 55),
                                _buildTableHeaderCell('+/-', 45),
                                _buildTableHeaderCell('Putts', 55),
                                _buildTableHeaderCell('GIR', 50),
                                _buildTableHeaderCell('FWY', 50),
                                _buildTableHeaderCell('Chips', 55),
                                _buildTableHeaderCell('Pen', 50),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Table Body (scrollable)
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              children: _holes!.map((hole) {
                                final score = _holeScores[hole.holeNumber];
                                final par = hole.par ?? 4;
                                final toPar = score != null ? score - par : null;
                                final putts = _holePutts[hole.holeNumber];
                                final gir = _holeGreenInRegulation[hole.holeNumber];
                                final fairway = _holeFairwayHit[hole.holeNumber];
                                final chips = _holeChipShots[hole.holeNumber];
                                final penalties = _holePenalties[hole.holeNumber];
                                final isCurrentHole = hole.holeNumber == currentHole?.holeNumber;

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      setState(() {
                                        _currentHoleIndex = _holes!.indexOf(hole);
                                        _currentScore = score;
                                      });
                                      _moveCameraToCurrentHole();
                                      _showScoreBottomSheet();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: isCurrentHole
                                            ? const Color(0xFFF0F7ED)
                                            : score != null
                                                ? const Color(0xFFFAFBFC)
                                                : Colors.white,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 1,
                                          ),
                                          left: isCurrentHole
                                              ? const BorderSide(
                                                  color: Color(0xFF6B8E4E),
                                                  width: 3,
                                                )
                                              : BorderSide.none,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          _buildTableDataCell(
                                            '${hole.holeNumber}',
                                            50,
                                            FontWeight.bold,
                                            isCurrentHole
                                                ? const Color(0xFF6B8E4E)
                                                : const Color(0xFF2D3E1F),
                                          ),
                                          _buildTableDataCell(
                                            '$par',
                                            45,
                                            FontWeight.w500,
                                            Colors.grey[700]!,
                                          ),
                                          _buildTableDataCell(
                                            score != null ? '$score' : '-',
                                            55,
                                            FontWeight.bold,
                                            score != null
                                                ? (toPar! > 0
                                                    ? const Color(0xFFE53935)
                                                    : toPar < 0
                                                        ? const Color(0xFF43A047)
                                                        : const Color(0xFF2D3E1F))
                                                : Colors.grey[400]!,
                                          ),
                                          _buildTableDataCell(
                                            toPar != null
                                                ? (toPar == 0 ? 'E' : '${toPar > 0 ? '+' : ''}$toPar')
                                                : '-',
                                            45,
                                            FontWeight.w600,
                                            toPar != null
                                                ? (toPar > 0
                                                    ? const Color(0xFFE53935)
                                                    : toPar < 0
                                                        ? const Color(0xFF43A047)
                                                        : Colors.grey[700]!)
                                                : Colors.grey[400]!,
                                          ),
                                          _buildTableDataCell(
                                            putts != null ? '$putts' : '-',
                                            55,
                                            FontWeight.normal,
                                            Colors.grey[800]!,
                                          ),
                                          _buildTableIconCell(gir, 50),
                                          _buildTableIconCell(fairway, 50),
                                          _buildTableDataCell(
                                            chips != null ? '$chips' : '-',
                                            55,
                                            FontWeight.normal,
                                            Colors.grey[800]!,
                                          ),
                                          _buildTableDataCell(
                                            penalties != null ? '$penalties' : '-',
                                            50,
                                            FontWeight.w500,
                                            penalties != null && penalties > 0
                                                ? const Color(0xFFE53935)
                                                : Colors.grey[800]!,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
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

  Widget _buildMainStatCard(String label, String value, IconData icon, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: const Color(0xFF6B8E4E).withOpacity(0.7),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3E1F),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableDataCell(String text, double width, FontWeight weight, Color color) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: weight,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTableIconCell(bool? value, double width) {
    return SizedBox(
      width: width,
      child: Center(
        child: value == null
            ? Text(
                '-',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[400],
                ),
              )
            : Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: value
                      ? const Color(0xFF43A047).withOpacity(0.1)
                      : const Color(0xFFE53935).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  value ? Icons.check_rounded : Icons.close_rounded,
                  size: 16,
                  color: value ? const Color(0xFF43A047) : const Color(0xFFE53935),
                ),
              ),
      ),
    );
  }

  int get totalScore {
    int total = 0;
    _holeScores.forEach((holeNumber, score) {
      total += score;
    });
    return total;
  }

  void _showScoreBottomSheet() {
    if (currentHole == null) return;

    final doublePar = (currentHole!.par ?? 4) * 2;
    final holeNumber = currentHole!.holeNumber;
    final bool isHoleCompleted = _holeScores.containsKey(holeNumber);

    // Load all saved stats for this hole if it's completed
    if (isHoleCompleted) {
      if (_currentScore == null) _currentScore = _holeScores[holeNumber];
      if (_currentPutts == null) _currentPutts = _holePutts[holeNumber];
      if (_currentChipShots == null) _currentChipShots = _holeChipShots[holeNumber];
      if (_currentPenalties == null) _currentPenalties = _holePenalties[holeNumber];
      if (_currentGreenInRegulation == null) _currentGreenInRegulation = _holeGreenInRegulation[holeNumber];
      if (_currentFairwayHit == null) _currentFairwayHit = _holeFairwayHit[holeNumber];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Padding(
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
                        setState(() {
                          _currentScore = null;
                          _currentPutts = null;
                          _currentChipShots = null;
                          _currentPenalties = null;
                          _currentGreenInRegulation = null;
                          _currentFairwayHit = null;
                          _isCustomScoreMode = false;
                          _customScoreController.clear();
                        });
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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Score',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        _isCustomScoreMode = !_isCustomScoreMode;
                        if (!_isCustomScoreMode) {
                          _customScoreController.clear();
                          if (_customScoreController.text.isNotEmpty) {
                            _currentScore = int.tryParse(_customScoreController.text);
                          }
                        } else {
                          _currentScore = null;
                        }
                      });
                    },
                    child: Text(
                      _isCustomScoreMode ? 'Presets' : 'Other',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B8E4E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isCustomScoreMode)
                TextField(
                  controller: _customScoreController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter score',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6B8E4E), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6B8E4E), width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    setModalState(() {
                      _currentScore = int.tryParse(value);
                    });
                  },
                )
              else
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

              const SizedBox(height: 24),

              // Green in Regulation
              const Text(
                'Green in Regulation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setModalState(() {
                          _currentGreenInRegulation = true;
                        });
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: _currentGreenInRegulation == true
                              ? const Color(0xFF6B8E4E)
                              : Colors.white,
                          border: Border.all(
                            color: _currentGreenInRegulation == true
                                ? const Color(0xFF6B8E4E)
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.check,
                          size: 32,
                          color: _currentGreenInRegulation == true
                              ? Colors.white
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setModalState(() {
                          _currentGreenInRegulation = false;
                        });
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: _currentGreenInRegulation == false
                              ? Colors.red[400]
                              : Colors.white,
                          border: Border.all(
                            color: _currentGreenInRegulation == false
                                ? Colors.red[400]!
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 32,
                          color: _currentGreenInRegulation == false
                              ? Colors.white
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Fairway Hit
              const Text(
                'Fairway Hit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setModalState(() {
                          _currentFairwayHit = true;
                        });
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: _currentFairwayHit == true
                              ? const Color(0xFF6B8E4E)
                              : Colors.white,
                          border: Border.all(
                            color: _currentFairwayHit == true
                                ? const Color(0xFF6B8E4E)
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.check,
                          size: 32,
                          color: _currentFairwayHit == true
                              ? Colors.white
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setModalState(() {
                          _currentFairwayHit = false;
                        });
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: _currentFairwayHit == false
                              ? Colors.red[400]
                              : Colors.white,
                          border: Border.all(
                            color: _currentFairwayHit == false
                                ? Colors.red[400]!
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 32,
                          color: _currentFairwayHit == false
                              ? Colors.white
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Chip Shots
              const Text(
                'Chip Shots',
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
                    final chipShots = index;
                    final isSelected = _currentChipShots == chipShots;
                    return _buildScoreChip(
                      chipShots,
                      isSelected,
                      () {
                        setModalState(() {
                          _currentChipShots = chipShots;
                        });
                      },
                    );
                  }),
                  _buildScoreChip(
                    -1,
                    _currentChipShots == 4,
                    () {
                      setModalState(() {
                        _currentChipShots = 4;
                      });
                    },
                    label: '4+',
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Penalties
              const Text(
                'Penalties',
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
                    final penalties = index;
                    final isSelected = _currentPenalties == penalties;
                    return _buildScoreChip(
                      penalties,
                      isSelected,
                      () {
                        setModalState(() {
                          _currentPenalties = penalties;
                        });
                      },
                    );
                  }),
                  _buildScoreChip(
                    -1,
                    _currentPenalties == 4,
                    () {
                      setModalState(() {
                        _currentPenalties = 4;
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

              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 24),
                ],
              ),
            ),
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
    final holeNumber = currentHole!.holeNumber;

    // Save all hole stats
    _holeScores[holeNumber] = _currentScore!;
    if (_currentPutts != null) _holePutts[holeNumber] = _currentPutts!;
    if (_currentChipShots != null) _holeChipShots[holeNumber] = _currentChipShots!;
    if (_currentPenalties != null) _holePenalties[holeNumber] = _currentPenalties!;
    if (_currentGreenInRegulation != null) _holeGreenInRegulation[holeNumber] = _currentGreenInRegulation!;
    if (_currentFairwayHit != null) _holeFairwayHit[holeNumber] = _currentFairwayHit!;

    await _saveRoundState();

    if (_currentHoleIndex < (_holes?.length ?? 0) - 1) {
      setState(() {
        _currentHoleIndex++;
        _currentScore = null;
        _currentPutts = null;
        _currentChipShots = null;
        _currentPenalties = null;
        _currentGreenInRegulation = null;
        _currentFairwayHit = null;
        _isCustomScoreMode = false;
        _customScoreController.clear();
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4C4E52).withOpacity(0.95),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
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
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Mid Green',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _distanceToGreen != null
                                          ? '${_distanceToGreen!.round()}y'
                                          : 'Calc...',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
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
                                    size: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isHeaderExpanded)
                            Flexible(
                              child: Container(
                                height: 56,
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4C4E52).withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Par',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${currentHole!.par ?? "?"}',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            teeColor ?? '?',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${currentTeeBox?.yards ?? "?"}y',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'HCP',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${currentHole!.handicap ?? "?"}',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
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

            // Location Reset Button
            Positioned(
              bottom: 24,
              left: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _moveCameraToCurrentHole,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.my_location,
                        color: Color(0xFF6B8E4E),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (_holeScores.isNotEmpty)
              Positioned(
                bottom: 24,
                right: 24,
                child: GestureDetector(
                  onTap: _showScorecardModal,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _relativeToPar > 0
                                ? Colors.red
                                : _relativeToPar < 0
                                    ? Colors.green
                                    : Colors.grey[800],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          width: 1,
                          height: 16,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'T${_holeScores.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (currentHole != null)
              Positioned(
                bottom: 24,
                left: 90,
                right: 90,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                   child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Left Arrow (always present for layout consistency)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _currentHoleIndex > 0
                                ? const Color(0xFF4C4E52).withOpacity(0.95)
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                          child: _currentHoleIndex > 0
                              ? Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _currentHoleIndex--;
                                        final holeNumber = currentHole!.holeNumber;
                                        _currentScore = _holeScores[holeNumber];
                                        _currentPutts = _holePutts[holeNumber];
                                        _currentChipShots = _holeChipShots[holeNumber];
                                        _currentPenalties = _holePenalties[holeNumber];
                                        _currentGreenInRegulation = _holeGreenInRegulation[holeNumber];
                                        _currentFairwayHit = _holeFairwayHit[holeNumber];
                                        _isCustomScoreMode = false;
                                        _customScoreController.clear();
                                      });
                                      _updateDistanceToGreen();
                                      _setMarkerToHoleCenter();
                                      _moveCameraToCurrentHole();
                                    },
                                    child: const Center(
                                      child: Icon(
                                        Icons.chevron_left,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox(), // Empty space when no arrow
                        ),
                        Material(
                          color: const Color(0xFF6B8E4E),
                          borderRadius: BorderRadius.horizontal(
                            left: _currentHoleIndex == 0
                                ? const Radius.circular(16)
                                : Radius.zero,
                            right: _currentHoleIndex == (_holes?.length ?? 0) - 1
                                ? const Radius.circular(16)
                                : Radius.zero,
                          ),
                          child: InkWell(
                            onTap: _showScoreBottomSheet,
                            borderRadius: BorderRadius.horizontal(
                              left: _currentHoleIndex == 0
                                  ? const Radius.circular(16)
                                  : Radius.zero,
                              right: _currentHoleIndex == (_holes?.length ?? 0) - 1
                                  ? const Radius.circular(16)
                                  : Radius.zero,
                            ),
                            child: Container(
                              width: 100,
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _holeScores.containsKey(currentHole!.holeNumber)
                                        ? 'Edit ${currentHole!.holeNumber}'
                                        : 'Hole ${currentHole!.holeNumber}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  const Text(
                                    'Enter Score',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Right Arrow (always present for layout consistency)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _currentHoleIndex < (_holes?.length ?? 0) - 1
                                ? const Color(0xFF4C4E52).withOpacity(0.95)
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: _currentHoleIndex < (_holes?.length ?? 0) - 1
                              ? Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _currentHoleIndex++;
                                        final holeNumber = currentHole!.holeNumber;
                                        _currentScore = _holeScores[holeNumber];
                                        _currentPutts = _holePutts[holeNumber];
                                        _currentChipShots = _holeChipShots[holeNumber];
                                        _currentPenalties = _holePenalties[holeNumber];
                                        _currentGreenInRegulation = _holeGreenInRegulation[holeNumber];
                                        _currentFairwayHit = _holeFairwayHit[holeNumber];
                                        _isCustomScoreMode = false;
                                        _customScoreController.clear();
                                      });
                                      _updateDistanceToGreen();
                                      _setMarkerToHoleCenter();
                                      _moveCameraToCurrentHole();
                                    },
                                    child: const Center(
                                      child: Icon(
                                        Icons.chevron_right,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox(), // Empty space when no arrow
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