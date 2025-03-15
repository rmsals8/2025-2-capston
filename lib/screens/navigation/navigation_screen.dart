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
  final String transportMode; // 추가: 이동 수단 정보
  const NavigationScreen({
    Key? key,
    required this.startLocation,
    required this.endLocation,
    this.transportMode = 'DRIVING', // 기본값 설정
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
  bool _isLoading = true;
  String? _errorMessage;
  bool _isMapInitialized = false;
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
    _initializeMap();
  }
  Future<void> _initializeMap() async {
    try {
      final locationProvider = context.read<LocationProvider>();
      await locationProvider.startTracking();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '위치 추적 시작 실패: $e';
        _isLoading = false;
      });
    }
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
    try {
      final routeProvider = context.read<RouteProvider>();

      // 마커 생성
      _markers = {
        Marker(
          markerId: const MarkerId('start'),
          position: widget.startLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: '출발지'),
        ),
        Marker(
          markerId: const MarkerId('end'),
          position: widget.endLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: '도착지'),
        ),
      };

      // 경로선 생성 (단순 직선)
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [widget.startLocation, widget.endLocation],
          color: _getTransportModeColor(widget.transportMode),
          width: 5,
        ),
      };

      setState(() {});

      // 지도 중심 이동
      _fitMapToBounds();
    } catch (e) {
      print('Map elements update error: $e');
    }
  }

  Color _getTransportModeColor(String transportMode) {
    switch (transportMode.toUpperCase()) {
      case 'WALK':
        return Colors.green;
      case 'TRANSIT':
        return Colors.blue;
      case 'DRIVING':
        return Colors.red;
      default:
        return Colors.purple;
    }
  }

  void _fitMapToBounds() {
    if (_mapController == null) return;

    // 마커들을 포함하는 영역 계산
    final double minLat = widget.startLocation.latitude < widget.endLocation.latitude
        ? widget.startLocation.latitude : widget.endLocation.latitude;
    final double maxLat = widget.startLocation.latitude > widget.endLocation.latitude
        ? widget.startLocation.latitude : widget.endLocation.latitude;
    final double minLng = widget.startLocation.longitude < widget.endLocation.longitude
        ? widget.startLocation.longitude : widget.endLocation.longitude;
    final double maxLng = widget.startLocation.longitude > widget.endLocation.longitude
        ? widget.startLocation.longitude : widget.endLocation.longitude;

    // 여백 추가
    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );

    // 지도 이동
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
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
      appBar: AppBar(
        title: const Text('내비게이션'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.startLocation,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (!_isMapInitialized) {
                _updateMapElements();
                _isMapInitialized = true;
              }
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '내비게이션 시작됨',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '이동 수단: ${_getTransportModeText(widget.transportMode)}',
                    style: TextStyle(
                      color: _getTransportModeColor(widget.transportMode),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('내비게이션 종료'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _fitMapToBounds,
                          child: const Text('전체 경로 보기'),
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
    );
  }

  String _getTransportModeText(String transportMode) {
    switch (transportMode.toUpperCase()) {
      case 'WALK':
        return '도보';
      case 'TRANSIT':
        return '대중교통';
      case 'DRIVING':
        return '자동차';
      default:
        return transportMode;
    }
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