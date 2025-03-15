// lib/screens/navigation/route_navigation_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trip_helper/models/route.dart' as trip_route;
import '../../providers/route_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class RouteNavigationScreen extends StatefulWidget {
  final trip_route.Route route;
  final String navigationId;

  const RouteNavigationScreen({
    Key? key,
    required this.route,
    required this.navigationId,
  }) : super(key: key);

  @override
  State<RouteNavigationScreen> createState() => _RouteNavigationScreenState();
}

class _RouteNavigationScreenState extends State<RouteNavigationScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _startLocationUpdates() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        context.read<RouteProvider>().updateLocation(
          position.latitude,
          position.longitude,
          speed: position.speed,
          heading: position.heading,
        );

        _mapController?.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내비게이션'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.route.segments.first.startLat,
                widget.route.segments.first.startLon,
              ),
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            polylines: _buildPolylines(),
            markers: _buildMarkers(),
          ),
          _buildNavigationInfo(),
        ],
      ),
    );
  }

  Set<Polyline> _buildPolylines() {
    return Set<Polyline>.from(widget.route.segments.map((segment) {
      return Polyline(
        polylineId: PolylineId(segment.id),
        points: [
          LatLng(segment.startLat, segment.startLon),
          LatLng(segment.endLat, segment.endLon),
        ],
        color: Colors.blue,
        width: 5,
      );
    }));
  }

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('start'),
        position: LatLng(
          widget.route.segments.first.startLat,
          widget.route.segments.first.startLon,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: LatLng(
          widget.route.segments.last.endLat,
          widget.route.segments.last.endLon,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  Widget _buildNavigationInfo() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '총 거리: ${widget.route.totalDistance.toStringAsFixed(1)}km',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '예상 소요시간: ${widget.route.totalDuration}분',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}