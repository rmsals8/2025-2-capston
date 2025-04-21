import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/route.dart' as route_model;
import '../../providers/route_provider.dart';

class RouteMap extends StatefulWidget {
  final List<route_model.Route> routes;
  final route_model.Route? selectedRoute;
  final Function(route_model.Route)? onRouteSelected;

  const RouteMap({
    Key? key,
    required this.routes,
    this.selectedRoute,
    this.onRouteSelected,
  }) : super(key: key);

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  static const List<Color> routeColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    _updateMapElements();
  }

  @override
  void didUpdateWidget(RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedRoute != oldWidget.selectedRoute ||
        widget.routes != oldWidget.routes) {
      _updateMapElements();
    }
  }

  void _updateMapElements() {
    setState(() {
      _markers = _createMarkers();
      _polylines = _createPolylines();
    });

    if (widget.selectedRoute != null && _mapController != null) {
      _fitToRoute(widget.selectedRoute!);
    }
  }

  Set<Marker> _createMarkers() {
    Set<Marker> markers = {};
    final List<Color> markerColors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange
    ];

    // 첫 번째 장소 (출발지)
    if (widget.routes.isNotEmpty) {
      final firstRoute = widget.routes.first;
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(
              firstRoute.segments.first.startLat,
              firstRoute.segments.first.startLon
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
              title: '1. ${firstRoute.segments.first.startLocation}',
              snippet: '출발지'
          ),
        ),
      );
    }

    // 중간 경유지들
    widget.routes.asMap().forEach((index, route) {
      markers.add(
        Marker(
          markerId: MarkerId('waypoint_$index'),
          position: LatLng(
              route.segments.first.endLat,
              route.segments.first.endLon
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue + (index * 30.0)
          ),
          infoWindow: InfoWindow(
              title: '${index + 2}. ${route.segments.first.endLocation}',
              snippet: '경유지'
          ),
        ),
      );
    });

    return markers;
  }


  double _getMarkerHue(int index) {
    final hues = [
      BitmapDescriptor.hueRed,
      BitmapDescriptor.hueBlue,
      BitmapDescriptor.hueGreen,
      BitmapDescriptor.hueViolet,
      BitmapDescriptor.hueOrange,
      BitmapDescriptor.hueMagenta,
      BitmapDescriptor.hueCyan,
      BitmapDescriptor.hueRose,
    ];
    return hues[index % hues.length];
  }

// route_map.dart의 _createPolylines 메서드
  Set<Polyline> _createPolylines() {
    Set<Polyline> polylines = {};
    final List<Color> routeColors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange
    ];

    widget.routes.asMap().forEach((index, route) {
      for (var segment in route.segments) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('${route.id}_${segment.id}'),
            points: [
              LatLng(segment.startLat, segment.startLon),
              LatLng(segment.endLat, segment.endLon),
            ],
            color: routeColors[index % routeColors.length],
            width: route == widget.selectedRoute ? 5 : 3,
            patterns: [
              PatternItem.dash(20.0),
              PatternItem.gap(10.0),
            ],
          ),
        );
      }
    });

    return polylines;
  }

  void _fitToRoute(route_model.Route route) {
    if (_mapController == null) return;

    List<LatLng> points = [];
    for (var segment in route.segments) {
      points.add(LatLng(segment.startLat, segment.startLon));
      points.add(LatLng(segment.endLat, segment.endLon));
    }

    if (points.isEmpty) return;

    // 모든 경로 지점을 포함하는 경계 상자 계산
    double minLat = points.map((p) => p.latitude).reduce(min);
    double maxLat = points.map((p) => p.latitude).reduce(max);
    double minLng = points.map((p) => p.longitude).reduce(min);
    double maxLng = points.map((p) => p.longitude).reduce(max);

    // 경계 상자에 패딩 추가하여 카메라 이동
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50, // 패딩
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.routes.isEmpty) {
      return const Center(child: Text('표시할 경로가 없습니다.'));
    }

    final initialRoute = widget.routes.first;
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          initialRoute.segments.first.startLat,
          initialRoute.segments.first.startLon,
        ),
        zoom: 13,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        if (widget.selectedRoute != null) {
          _fitToRoute(widget.selectedRoute!);
        }
      },
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      compassEnabled: true,
      mapToolbarEnabled: false,
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

double min(double a, double b) => a < b ? a : b;
double max(double a, double b) => a > b ? a : b;