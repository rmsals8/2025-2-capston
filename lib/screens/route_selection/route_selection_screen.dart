import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/navigation_provider.dart';
import '../../models/route.dart' as trip_route;
import '../../widgets/route/navigation_controls.dart';
import '../../widgets/map/navigation_map.dart';
import '../navigation/navigation_screen.dart';

class RouteSelectionScreen extends StatefulWidget {
  final LatLng startLocation;
  final LatLng endLocation;

  const RouteSelectionScreen({
    Key? key,
    required this.startLocation,
    required this.endLocation,
  }) : super(key: key);

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initializeMapData();
  }

  void _initializeMapData() {
    _markers = {
      Marker(
        markerId: const MarkerId('start'),
        position: widget.startLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: widget.endLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [widget.startLocation, widget.endLocation],
        color: Colors.blue,
        width: 5,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('경로 선택'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<NavigationProvider>(
        builder: (context, provider, child) {
          if (provider.error != null) {
            return Center(
              child: Text('Error: ${provider.error}'),
            );
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.startLocation,
                  zoom: 15,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  _fitBounds();
                },
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
              ),
              if (provider.selectedRoute != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '총 거리: ${provider.selectedRoute!.distance.toStringAsFixed(1)}km',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '예상 소요시간: ${provider.selectedRoute!.duration}분',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NavigationScreen(
                                    startLocation: widget.startLocation,
                                    endLocation: widget.endLocation,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '내비게이션 시작',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _fitBounds() {
    if (_mapController == null) return;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        min(widget.startLocation.latitude, widget.endLocation.latitude),
        min(widget.startLocation.longitude, widget.endLocation.longitude),
      ),
      northeast: LatLng(
        max(widget.startLocation.latitude, widget.endLocation.latitude),
        max(widget.startLocation.longitude, widget.endLocation.longitude),
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        100.0, // 패딩
      ),
    );
  }

  double min(double a, double b) => a < b ? a : b;
  double max(double a, double b) => a > b ? a : b;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}