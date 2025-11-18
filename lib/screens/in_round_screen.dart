import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:golf_tracker_app/models/models.dart';
import 'package:golf_tracker_app/services/overpass_api_service.dart';

class InRoundScreen extends StatefulWidget {
  final Course course;
  
  const InRoundScreen({
    super.key,
    required this.course,
  });

  @override
  State<InRoundScreen> createState() => _InRoundScreenState();
}

class _InRoundScreenState extends State<InRoundScreen> {
  late GoogleMapController mapController;
  final PanelController _panelController = PanelController();
  final OverpassApiService _overpassApiService = OverpassApiService();
  
  Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  bool _isLoadingHoleData = true;
  List<Hole>? _holes;

  @override
  void initState() {
    super.initState();
    _loadCourseData();
  }

  Future<void> _loadCourseData() async {
    setState(() {
      _isLoadingHoleData = true;
    });

    try {
      // Add main course marker
      _markers.add(
        Marker(
          markerId: const MarkerId('course_main'),
          position: LatLng(
            widget.course.location.latitude!,
            widget.course.location.longitude!,
          ),
          infoWindow: InfoWindow(
            title: widget.course.courseName,
            snippet: 'Golf Course',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );

      // Fetch hole details (tee boxes and greens)
      final courseDetails = await _overpassApiService.fetchCourseDetails(
        widget.course.courseId,
      );

      final holes = courseDetails.holes ?? [];

      // Add markers for tee boxes and greens
      for (var hole in holes) {
        // Add markers for each tee box
        if (hole.teeBoxes != null) {
          for (var teeBox in hole.teeBoxes!) {
            if (teeBox.location != null) {
              _markers.add(
                Marker(
                  markerId: MarkerId('tee_${hole.holeNumber}_${teeBox.tee}'),
                  position: LatLng(
                    teeBox.location!.latitude!,
                    teeBox.location!.longitude!,
                  ),
                  infoWindow: InfoWindow(
                    title: 'Hole ${hole.holeNumber} - ${teeBox.tee} Tee',
                    snippet: 'Par ${teeBox.par ?? hole.par} • ${teeBox.yards ?? "N/A"} yards',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                ),
              );
            }
          }
        }

        // Add green marker (center point)
        if (hole.greenLocation != null) {
          _markers.add(
            Marker(
              markerId: MarkerId('green_${hole.holeNumber}'),
              position: LatLng(
                hole.greenLocation!.latitude!,
                hole.greenLocation!.longitude!,
              ),
              infoWindow: InfoWindow(
                title: 'Hole ${hole.holeNumber} Green',
                snippet: 'Par ${hole.par}',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          );
        }

        // Draw green polygon if coordinates are available
        if (hole.greenCoordinates != null && hole.greenCoordinates!.isNotEmpty) {
          _polygons.add(
            Polygon(
              polygonId: PolygonId('green_polygon_${hole.holeNumber}'),
              points: hole.greenCoordinates!
                  .map((coord) => LatLng(coord.latitude!, coord.longitude!))
                  .toList(),
              fillColor: Colors.green.withOpacity(0.3),
              strokeColor: Colors.green,
              strokeWidth: 2,
            ),
          );
        }

        // Add hazard markers
        if (hole.hazards != null) {
          for (int i = 0; i < hole.hazards!.length; i++) {
            final hazard = hole.hazards![i];
            if (hazard.latitude != null && hazard.longitude != null) {
              _markers.add(
                Marker(
                  markerId: MarkerId('hazard_${hole.holeNumber}_$i'),
                  position: LatLng(hazard.latitude!, hazard.longitude!),
                  infoWindow: InfoWindow(
                    title: 'Hazard - Hole ${hole.holeNumber}',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                ),
              );
            }
          }
        }
      }

      setState(() {
        _holes = holes;
        _isLoadingHoleData = false;
      });
    } catch (e) {
      print('Error loading course data: $e');
      setState(() {
        _isLoadingHoleData = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading hole data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.courseName),
        backgroundColor: const Color(0xFF6B8E4E),
        foregroundColor: Colors.white,
      ),
      body: SlidingUpPanel(
        controller: _panelController,
        minHeight: 100,
        maxHeight: MediaQuery.of(context).size.height * 0.7,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
        panel: _buildPanel(),
        body: GoogleMap(
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
          myLocationButtonEnabled: true,
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return Column(
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 20),
        // Panel content
        Expanded(
          child: _isLoadingHoleData
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF6B8E4E)),
                      SizedBox(height: 16),
                      Text('Loading course details...'),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    Text(
                      widget.course.courseName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard('Total Holes', '${_holes?.length ?? 18}'),
                    _buildInfoCard('Par', '${widget.course.totalPar ?? 72}'),
                    if (_holes != null && _holes!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Hole Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._holes!.map((hole) => _buildHoleCard(hole)),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement start round functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Starting round at ${widget.course.courseName}'),
                            backgroundColor: const Color(0xFF6B8E4E),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF6B8E4E),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Start Round'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoleCard(Hole hole) {
    // Get the first tee box for display (or you can show all)
    final firstTee = hole.teeBoxes?.firstOrNull;
    final yardage = firstTee?.yards?.toString() ?? "N/A";
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF6B8E4E),
          child: Text(
            '${hole.holeNumber}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text('Hole ${hole.holeNumber}'),
        subtitle: Text('Par ${hole.par} • $yardage yards'),
        trailing: IconButton(
          icon: const Icon(Icons.location_on),
          onPressed: () {
            // Zoom to first tee box on map
            if (firstTee?.location != null) {
              mapController.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(
                    firstTee!.location!.latitude!,
                    firstTee.location!.longitude!,
                  ),
                  18.0,
                ),
              );
              _panelController.close();
            }
          },
        ),
        children: [
          if (hole.teeBoxes != null && hole.teeBoxes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tee Boxes:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...hole.teeBoxes!.map((teeBox) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${teeBox.tee} Tee'),
                        Text('${teeBox.yards ?? "N/A"} yards'),
                      ],
                    ),
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}