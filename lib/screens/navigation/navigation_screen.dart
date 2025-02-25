// lib/screens/navigation/navigation_screen.dart
import '../../models/route.dart' as app_route;  // 이렇게 import 추가
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/navigation/turn_by_turn_guide.dart';
import '../../widgets/navigation/navigation_status_panel.dart';
import 'dart:math' ;
import '../../providers/route_provider.dart';
class NavigationScreen extends StatefulWidget {
  final LatLng startLocation;
  final LatLng endLocation;

  const NavigationScreen({
    Key? key,
    required this.startLocation,
    required this.endLocation,
  }) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _mapController;
  bool _isInitialized = false;
  bool _isMapReady = false;
  bool _isNavigationInitialized = false;  // 클래스 멤버 변수로 추가
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeNavigation();
      _isInitialized = true;
    }
  }
  @override
  void initState() {
    super.initState();
    _loadMapElements();
  }

  Future<void> _loadMapElements() async {
    final routeProvider = context.read<RouteProvider>();
    final markers = await routeProvider.createMarkers();

    setState(() {
      _markers = markers;
      _polylines = routeProvider.createPolylines();
    });
  }
  void _updateMapElements() {
    setState(() {
      _markers = _createMarkers();
      _polylines = _createPolylines();
    });
  }



  Set<Marker> _createMarkers() {
    final Set<Marker> markers = {};
    final routeProvider = context.read<RouteProvider>();

    routeProvider.routes.asMap().forEach((index, route) {
      // 시작점 마커
      markers.add(
        Marker(
          markerId: MarkerId('start_$index'),
          position: LatLng(
              route.segments.first.startLat,
              route.segments.first.startLon
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              (index * 30.0) % 330.0  // 다른 색상의 마커
          ),
          infoWindow: InfoWindow(title: route.segments.first.startLocation),
        ),
      );

      // 도착점 마커
      markers.add(
        Marker(
          markerId: MarkerId('end_$index'),
          position: LatLng(
              route.segments.last.endLat,
              route.segments.last.endLon
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              (index * 30.0) % 330.0
          ),
          infoWindow: InfoWindow(title: route.segments.last.endLocation),
        ),
      );
    });

    return markers;
  }

  Set<Polyline> _createPolylines() {
    final Set<Polyline> polylines = {};
    final routeProvider = context.read<RouteProvider>();

    routeProvider.routes.asMap().forEach((index, route) {
      List<LatLng> points = route.segments.expand((segment) => [
        LatLng(segment.startLat, segment.startLon),
        LatLng(segment.endLat, segment.endLon),
      ]).toList();

      polylines.add(
        Polyline(
          polylineId: PolylineId('route_$index'),
          points: points,
          color: RouteProvider.routeColors[index % RouteProvider.routeColors.length],
          width: 5,
        ),
      );
    });

    return polylines;
  }

  void _fitAllRoutesBounds() {
    if (_mapController == null) return;

    final routeProvider = context.read<RouteProvider>();
    if (routeProvider.routes.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var route in routeProvider.routes) {
      for (var segment in route.segments) {
        minLat = min(minLat, segment.startLat);
        maxLat = max(maxLat, segment.startLat);
        minLng = min(minLng, segment.startLon);
        maxLng = max(maxLng, segment.startLon);

        minLat = min(minLat, segment.endLat);
        maxLat = max(maxLat, segment.endLat);
        minLng = min(minLng, segment.endLon);
        maxLng = max(maxLng, segment.endLon);
      }
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }
  Future<void> _initializeNavigation() async {
    if (!_isMapReady) return;
    if (_isNavigationInitialized) return;

    try {
      final locationProvider = context.read<LocationProvider>();
      await locationProvider.startTracking();

      final navigationProvider = context.read<NavigationProvider>();
      await navigationProvider.startNavigation(widget.startLocation);

      setState(() {
        _isNavigationInitialized = true;
      });

      _moveCameraToLocation(widget.startLocation);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내비게이션 시작 실패: $e')),
        );
      }
    }
  }

  void _moveCameraToLocation(LatLng location) {
    if (_mapController == null || !_isMapReady) return;

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: 17,
          tilt: 45,
          bearing: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<NavigationProvider, LocationProvider>(
        builder: (context, navigationProvider, locationProvider, child) {
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.startLocation,
                  zoom: 15,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  _loadMapElements();
                  if (context.read<RouteProvider>().routes.isNotEmpty) {
                    _fitBounds(context.read<RouteProvider>().routes);
                  }
                },
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                compassEnabled: true,
                mapToolbarEnabled: false,
                tiltGesturesEnabled: false,
                zoomControlsEnabled: false,
              ),
              const TurnByTurnGuide(),
              const NavigationStatusPanel(),
            ],
          );
        },
      ),
    );
  }

  void _fitBounds(List<app_route.Route> routes) {  // 타입 수정
    if (_mapController == null || routes.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var route in routes) {
      for (var segment in route.segments) {
        // 시작점 확인
        minLat = min(minLat, segment.startLat);
        maxLat = max(maxLat, segment.startLat);
        minLng = min(minLng, segment.startLon);
        maxLng = max(maxLng, segment.startLon);

        // 도착점 확인
        minLat = min(minLat, segment.endLat);
        maxLat = max(maxLat, segment.endLat);
        minLng = min(minLng, segment.endLon);
        maxLng = max(maxLng, segment.endLon);
      }
    }

    // 여백 추가
    final double padding = 0.01;
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100,  // 패딩 값
      ),
    );
  }
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}