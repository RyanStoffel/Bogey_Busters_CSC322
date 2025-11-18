import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:golf_tracker_app/models/models.dart';
import 'package:golf_tracker_app/services/overpass_api_service.dart';
import 'dart:math' as math;

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

class _InRoundScreenState extends State<InRoundScreen> {
  late GoogleMapController mapController;
  final OverpassApiService _overpassApiService = OverpassApiService();
  
  Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  bool _isLoadingHoleData = true;
  List<Hole>? _holes;
  int _currentHoleIndex = 0;
  
  // Score tracking for current hole
  int? _currentScore;
  int? _currentPutts;

  @override
  void initState() {
    super.initState();
    _loadCourseData();
  }

  Hole? get currentHole {
    if (_holes == null || _holes!.isEmpty) return null;
    return _holes![_currentHoleIndex];
  }

  TeeBox? get currentTeeBox {
    if (currentHole?.teeBoxes == null) return null;
    return currentHole!.teeBoxes!.firstWhere(
      (tee) => tee.tee.toLowerCase() == widget.teeColor.toLowerCase(),
      orElse: () => currentHole!.teeBoxes!.first,
    );
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

      // Add markers for all holes
      for (var hole in holes) {
        print('\n--- Processing Hole ${hole.holeNumber} ---');
        print('Par: ${hole.par}, Handicap: ${hole.handicap}');
        print('Tee boxes available: ${hole.teeBoxes?.length ?? 0}');
        print('Green location: ${hole.greenLocation != null ? "Yes" : "No"}');
        
        // Add tee box markers for selected tee color
        if (hole.teeBoxes != null && hole.teeBoxes!.isNotEmpty) {
          final selectedTee = hole.teeBoxes!.firstWhere(
            (tee) => tee.tee.toLowerCase() == widget.teeColor.toLowerCase(),
            orElse: () => hole.teeBoxes!.first,
          );
          
          print('Selected tee: ${selectedTee.tee}, Location: ${selectedTee.location?.latitude}, ${selectedTee.location?.longitude}');
          
          if (selectedTee.location?.latitude != null && 
              selectedTee.location?.longitude != null) {
            _markers.add(
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
          _markers.add(
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
              _polygons.add(
                Polygon(
                  polygonId: PolygonId('green_polygon_${hole.holeNumber}'),
                  points: validCoords,
                  fillColor: Colors.green.withOpacity(0.3),
                  strokeColor: Colors.green,
                  strokeWidth: 2,
                ),
              );
              polygonsAdded++;
              print('✓ Added green polygon for hole ${hole.holeNumber} with ${validCoords.length} points');
            }
          } catch (e) {
            print('✗ Error creating polygon for hole ${hole.holeNumber}: $e');
          }
        }
      }

      print('\n=== Summary ===');
      print('Total holes: ${holes.length}');
      print('Tee markers added: $teeMarkersAdded');
      print('Green markers added: $greenMarkersAdded');
      print('Green polygons added: $polygonsAdded');
      print('Total markers: ${_markers.length}');

      setState(() {
        _holes = holes;
        _isLoadingHoleData = false;
      });

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
    if (teeBox?.location?.latitude == null || 
        teeBox?.location?.longitude == null) {
      print('Warning: Missing tee location for hole ${currentHole!.holeNumber}');
      // Try to use green location as fallback
      if (green?.latitude != null && green?.longitude != null) {
        try {
          await mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(green!.latitude!, green.longitude!),
                zoom: 17.0,
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
              zoom: 17.0,
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
              zoom: 17.0,
              tilt: 0,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error moving camera to hole: $e');
    }
  }

  double _calculateBearing(double startLat, double startLng, double endLat, double endLng) {
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

  Widget _buildScoreChip(int value, bool isSelected, VoidCallback onTap, {String? label}) {
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
    // TODO: Save hole score to database
    print('Hole ${currentHole!.holeNumber}: Score=$_currentScore, Putts=$_currentPutts');
    
    // Move to next hole
    if (_currentHoleIndex < (_holes?.length ?? 0) - 1) {
      setState(() {
        _currentHoleIndex++;
        _currentScore = null;
        _currentPutts = null;
      });
      _moveCameraToCurrentHole();
    } else {
      // Round complete
      _showRoundCompleteDialog();
    }
  }

  void _showRoundCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Round Complete!'),
        content: const Text('Congratulations on completing your round!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Finish'),
          ),
        ],
      ),
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
            markers: _markers,
            polygons: _polygons,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),
          
          // Hole Info Header
          if (currentHole != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                          radius: 20,
                          child: Text(
                            '#${currentHole!.holeNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Par ${currentHole!.par ?? "?"}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${widget.teeColor} ${currentTeeBox?.yards?.toString() ?? "?"} yds',
                              style: TextStyle(
                                fontSize: 12,
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
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Floating Hole Button
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
          
          // Back Button - positioned below the hole info header
          Positioned(
            top: MediaQuery.of(context).padding.top + 100,
            left: 16,
            child: Container(
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
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}