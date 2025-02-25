// lib/screens/route/route_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/route_provider.dart';
import '../../providers/navigation_provider.dart';
import '../navigation/navigation_screen.dart';
import '../../models/route.dart' as app_route;
import 'dart:math';
class RouteListScreen extends StatefulWidget {
  const RouteListScreen({Key? key}) : super(key: key);

  @override
  State<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends State<RouteListScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _loadMapElements();
  }
  Future<void> _loadMapElements() async {
    await _updateMapElements();
  }
  Future<void> _updateMapElements() async {
    final routeProvider = context.read<RouteProvider>();
    final markers = await routeProvider.createMarkers();

    setState(() {
      _markers = markers;
      _polylines = routeProvider.createPolylines();
    });
  }


  Set<Marker> _createMarkers(List<app_route.Route> routes) {
    Set<Marker> markers = {};
    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      if (route.segments.isEmpty) continue;

      markers.add(Marker(
        markerId: MarkerId('start_$i'),
        position: LatLng(
          route.segments.first.startLat,
          route.segments.first.startLon,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        infoWindow: InfoWindow(title: route.segments.first.startLocation),
      ));

      markers.add(Marker(
        markerId: MarkerId('end_$i'),
        position: LatLng(
          route.segments.last.endLat,
          route.segments.last.endLon,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        infoWindow: InfoWindow(title: route.segments.last.endLocation),
      ));
    }
    return markers;
  }

  Set<Polyline> _createPolylines(List<app_route.Route> routes) {
    Set<Polyline> polylines = {};
    final colors = [Colors.blue, Colors.red, Colors.green];

    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      if (route.segments.isEmpty) continue;

      List<LatLng> points = [];
      for (var segment in route.segments) {
        points.add(LatLng(segment.startLat, segment.startLon));
        points.add(LatLng(segment.endLat, segment.endLon));
      }

      polylines.add(Polyline(
        polylineId: PolylineId('route_$i'),
        points: points,
        color: colors[i % colors.length],
        width: 5,
      ));
    }
    return polylines;
  }

  void _fitBounds(List<app_route.Route> routes) {
    if (_mapController == null || routes.isEmpty) return;

    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;

    for (var route in routes) {
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

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
        100,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('추천 경로'),
      ),
      body: Consumer<RouteProvider>(
        builder: (context, routeProvider, child) {
          if (routeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (routeProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(routeProvider.error!),
                  ElevatedButton(
                    onPressed: routeProvider.clearError,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // 지도 영역
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      routeProvider.routes.isNotEmpty
                          ? routeProvider.routes.first.segments.first.startLat
                          : 35.5665,
                      routeProvider.routes.isNotEmpty
                          ? routeProvider.routes.first.segments.first.startLon
                          : 129.2780,
                    ),
                    zoom: 14,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _loadMapElements();  // 지도 생성 시 마커 로드
                    if (routeProvider.routes.isNotEmpty) {
                      _fitBounds(routeProvider.routes);
                    }
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                ),
              ),

              // 경로 리스트
              Expanded(
                child: ListView.builder(
                  itemCount: routeProvider.routes.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final route = routeProvider.routes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () async {
                          try {
                            routeProvider.selectRoute(route);
                            final navigationProvider = context.read<NavigationProvider>();
                            await navigationProvider.initializeNavigation(route);

                            final startLocation = LatLng(
                              route.segments.first.startLat,
                              route.segments.first.startLon,
                            );
                            final endLocation = LatLng(
                              route.segments.last.endLat,
                              route.segments.last.endLon,
                            );

                            if (context.mounted) {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NavigationScreen(
                                    startLocation: startLocation,
                                    endLocation: endLocation,
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('내비게이션 시작 실패: $e')),
                              );
                            }
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text('${index + 1}'),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${route.segments.first.startLocation} → ${route.segments.last.endLocation}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${route.totalDuration}분 • ${route.totalDistance.toStringAsFixed(1)}km',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}