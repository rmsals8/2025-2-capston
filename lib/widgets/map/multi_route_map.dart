// lib/widgets/map/multi_route_map.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/route_option.dart';
import '../../providers/location_provider.dart';
import 'waypoint_marker.dart';

class MultiRouteMap extends StatefulWidget {
  final List<RouteOption> routes;
  final RouteOption? selectedRoute;
  final Function(RouteOption)? onRouteSelected;

  const MultiRouteMap({
    Key? key,
    required this.routes,
    this.selectedRoute,
    this.onRouteSelected,
  }) : super(key: key);

  @override
  State<MultiRouteMap> createState() => _MultiRouteMapState();
}

class _MultiRouteMapState extends State<MultiRouteMap> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _updateMapElements();
  }

  @override
  void didUpdateWidget(MultiRouteMap oldWidget) {
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
    for (int i = 0; i < widget.routes.length; i++) {
      final route = widget.routes[i];
      if (route.segments.isEmpty) continue;

      // 시작점 마커
      WaypointMarker.create(
        id: 'start_$i',
        position: route.points.first,
        label: '출발',
        order: 1,
        isSelected: route == widget.selectedRoute,
      ).then((marker) => markers.add(marker));

      // 경유지 마커들
      for (int j = 1; j < route.segments.length; j++) {
        final index = j;
        WaypointMarker.create(
          id: 'waypoint_${i}_$index',
          position: route.points[index],
          label: '경유지 $index',
          order: index + 1,
          isSelected: route == widget.selectedRoute,
        ).then((marker) => markers.add(marker));
      }

      // 도착점 마커
      WaypointMarker.create(
        id: 'end_$i',
        position: route.points.last,
        label: '도착',
        order: route.points.length,
        isSelected: route == widget.selectedRoute,
      ).then((marker) => markers.add(marker));
    }
    return markers;
  }

  Set<Polyline> _createPolylines() {
    Set<Polyline> polylines = {};
    for (var route in widget.routes) {
      polylines.add(Polyline(
        polylineId: PolylineId(route.id),
        points: route.points,
        color: route.routeColor.withOpacity(route == widget.selectedRoute ? 1.0 : 0.5),
        width: route == widget.selectedRoute ? 5 : 3,
        patterns: route == widget.selectedRoute
            ? [PatternItem.dash(30), PatternItem.gap(20)]
            : [],
      ));
    }
    return polylines;
  }

  void _fitToRoute(RouteOption route) {
    if (_mapController == null) return;

    LatLngBounds bounds = _calculateRouteBounds(route);
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  LatLngBounds _calculateRouteBounds(RouteOption route) {
    if (route.points.isEmpty) {
      throw Exception('Route has no points');
    }

    double minLat = route.points.first.latitude;
    double maxLat = route.points.first.latitude;
    double minLng = route.points.first.longitude;
    double maxLng = route.points.first.longitude;


    for (var point in route.points) {
    minLat = math.min(minLat, point.latitude);
    maxLat = math.max(maxLat, point.latitude);
    minLng = math.min(minLng, point.longitude);
    maxLng = math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.routes.isNotEmpty
                ? widget.routes.first.points.first
                : const LatLng(37.5665, 126.9780), // 서울시청
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
          onTap: (latLng) {
            // 지도상의 경로 탭 감지 및 처리
            _handleMapTap(latLng);
          },
        );
      },
    );
  }

  void _handleMapTap(LatLng latLng) {
    // 탭한 위치와 가장 가까운 경로 찾기
    RouteOption? closestRoute;
    double minDistance = double.infinity;

    for (var route in widget.routes) {
      for (int i = 0; i < route.points.length - 1; i++) {
        double distance = _pointToLineDistance(
          latLng,
          route.points[i],
          route.points[i + 1],
        );
        if (distance < minDistance) {
          minDistance = distance;
          closestRoute = route;
        }
      }
    }

    // 일정 거리 이내에 경로가 있으면 선택
    if (minDistance < 0.01 && closestRoute != null) { // 약 1km
      widget.onRouteSelected?.call(closestRoute);
    }
  }

  double _pointToLineDistance(LatLng point, LatLng lineStart, LatLng lineEnd) {
    // 점과 직선 사이의 거리 계산 (Haversine formula 사용)
    double a = point.latitude - lineStart.latitude;
    double b = point.longitude - lineStart.longitude;
    double c = lineEnd.latitude - lineStart.latitude;
    double d = lineEnd.longitude - lineStart.longitude;

    double dot = a * c + b * d;
    double lenSq = c * c + d * d;
    double param = dot / lenSq;

    double xx, yy;

    if (param < 0) {
      xx = lineStart.latitude;
      yy = lineStart.longitude;
    } else if (param > 1) {
      xx = lineEnd.latitude;
      yy = lineEnd.longitude;
    } else {
      xx = lineStart.latitude + param * c;
      yy = lineStart.longitude + param * d;
    }

    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    return locationProvider.calculateDistance(
      point,
      LatLng(xx, yy),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}