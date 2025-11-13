import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class InRoundScreen extends StatefulWidget {
  @override
  _InRoundScreenState createState() => _InRoundScreenState();
}

class _InRoundScreenState extends State<InRoundScreen> {
  late GoogleMapController mapController;
  final PanelController _panelController = PanelController();
  
  // Example: Golf course location
  final LatLng _golfCourseLocation = LatLng(33.9533, -117.3962); // Riverside, CA area

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SlidingUpPanel(
        controller: _panelController,
        minHeight: 100,
        maxHeight: MediaQuery.of(context).size.height * 0.7,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
        panel: _buildPanel(),
        body: GoogleMap(
          onMapCreated: _onMapCreated,
          mapType: MapType.normal,
          initialCameraPosition: CameraPosition(
            target: _golfCourseLocation,
            zoom: 15.0,
          ),
          markers: {
            Marker(
              markerId: MarkerId('golf_course'),
              position: _golfCourseLocation,
              infoWindow: InfoWindow(
                title: 'Golf Course',
                snippet: 'Your current location',
              ),
            ),
          },
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
          margin: EdgeInsets.only(top: 12),
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        SizedBox(height: 20),
        // Panel content
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 20),
            children: [
              Text(
                'Golf Course Info',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              _buildInfoCard('Holes', '18'),
              _buildInfoCard('Par', '72'),
              _buildInfoCard('Distance', '6,800 yards'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Start round action
                },
                child: Text('Start Round'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 16)),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}