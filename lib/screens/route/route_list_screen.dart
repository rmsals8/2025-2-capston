// lib/screens/route/route_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/route_segment.dart';
import '../../providers/route_provider.dart';
import '../../providers/navigation_provider.dart';
import '../navigation/navigation_screen.dart';
import '../navigation/navigation_details_screen.dart'; // 추가
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

  // 교통 수단 선택 바텀시트 표시
// lib/screens/route/route_list_screen.dart의 _showTransportOptions 메서드 수정

  void _showTransportOptions(BuildContext context, app_route.Route route, int segmentIndex) {
    final segment = route.segments[segmentIndex];
    final startLat = segment.startLat;
    final startLon = segment.startLon;
    final endLat = segment.endLat;
    final endLon = segment.endLon;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${segment.startLocation}에서\n${segment.endLocation}까지',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('거리: ${segment.distance.toStringAsFixed(1)}km'),
            const SizedBox(height: 24),
            const Text(
              '이동 수단 선택',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTransportOption(
                  context,
                  Icons.directions_walk,
                  '도보',
                  Colors.green,
                      () => _startDirectNavigation(context, startLat, startLon, endLat, endLon, 'WALK', segment.startLocation, segment.endLocation),
                ),
                _buildTransportOption(
                  context,
                  Icons.directions_bus,
                  '대중교통',
                  Colors.blue,
                      () => _startDirectNavigation(context, startLat, startLon, endLat, endLon, 'TRANSIT', segment.startLocation, segment.endLocation),
                ),
                _buildTransportOption(
                  context,
                  Icons.directions_car,
                  '자동차',
                  Colors.red,
                      () => _startDirectNavigation(context, startLat, startLon, endLat, endLon, 'DRIVING', segment.startLocation, segment.endLocation),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

// 2. 내비게이션 직접 시작 메서드 추가 (이것이 핵심)
  // route_list_screen.dart 파일의 _startDirectNavigation 메서드 수정

  void _startDirectNavigation(BuildContext context, double startLat, double startLon, double endLat, double endLon, String transportMode, String startName, String endName) {
    // 좌표가 정상 범위에 있는지 확인하고 필요시 변환
    final normalizedStartLat = _normalizeCoordinate(startLat, true);
    final normalizedStartLon = _normalizeCoordinate(startLon, false);
    final normalizedEndLat = _normalizeCoordinate(endLat, true);
    final normalizedEndLon = _normalizeCoordinate(endLon, false);

    print('내비게이션 시작:');
    print('원본 출발지 좌표: $startLat, $startLon');
    print('변환 출발지 좌표: $normalizedStartLat, $normalizedStartLon');
    print('원본 도착지 좌표: $endLat, $endLon');
    print('변환 도착지 좌표: $normalizedEndLat, $normalizedEndLon');

    // 바로 NavigationDetailsScreen으로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationDetailsScreen(
          startLat: normalizedStartLat,
          startLon: normalizedStartLon,
          endLat: normalizedEndLat,
          endLon: normalizedEndLon,
          startName: startName,
          endName: endName,
          transportMode: transportMode,
        ),
      ),
    );
  }

// route_list_screen.dart 파일에 _normalizeCoordinate 함수 추가
  double _normalizeCoordinate(double value, bool isLatitude) {
    // 정상 범위 확인
    final double minValue = isLatitude ? -90.0 : -180.0;
    final double maxValue = isLatitude ? 90.0 : 180.0;

    // 이미 올바른 범위에 있는 경우 그대로 반환
    if (value >= minValue && value <= maxValue) {
      return value;
    }

    // 큰 숫자를 가진 좌표는 변환 필요
    if (value.abs() > 1000000) {
      // 숫자가 매우 큰 경우 (예: 355437482.0 -> 35.5437482)
      return value / 10000000.0;
    } else if (value.abs() > 100000) {
      // 숫자가 큰 경우 (예: 35543748.0 -> 35.543748)
      return value / 1000000.0;
    } else if (value.abs() > 10000) {
      // 중간 크기 (예: 3554374.0 -> 35.54374)
      return value / 100000.0;
    } else if (value.abs() > 1000) {
      // 더 작은 중간 크기 (예: 355437.0 -> 35.5437)
      return value / 10000.0;
    } else if (value.abs() > 180) {
      // 작은 숫자 (예: 355.0 -> 35.5)
      return value / 10.0;
    }

    // 다른 방법으로도 해결이 안 되면 한국 영역의 일반적인 좌표로 대체
    // 울산 지역의 평균 좌표를 반환 (울산광역시 남구)
    if (isLatitude) {
      return 35.5384;  // 울산 남구의 위도
    } else {
      return 129.3114; // 울산 남구의 경도
    }
  }

// 좌표가 유효한 한국 영역 내에 있는지 확인
  bool _isValidCoordinate(double lat, double lon) {
    // 한국 영역 대략적인 범위
    const double MIN_KOREA_LAT = 33.0;
    const double MAX_KOREA_LAT = 39.0;
    const double MIN_KOREA_LON = 124.0;
    const double MAX_KOREA_LON = 132.0;

    return lat >= MIN_KOREA_LAT && lat <= MAX_KOREA_LAT &&
        lon >= MIN_KOREA_LON && lon <= MAX_KOREA_LON;
  }
// lib/screens/route/route_list_screen.dart의 _findRouteWithMode 메서드 수정

  void _findRouteWithMode(BuildContext context, double startLat, double startLon, double endLat, double endLon, String transportMode, String startName, String endName) async {
    Navigator.pop(context);  // 바텀시트 닫기

    try {
      final routeProvider = context.read<RouteProvider>();

      // 로딩 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('경로를 찾는 중입니다...')),
      );

      await routeProvider.getDirectionsWithGoogleApi(startLat, startLon, endLat, endLon, transportMode);

      // 에러 발생 시 메시지 표시
      if (routeProvider.error != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(routeProvider.error!)),
        );
      }

      // 경로가 있으면 내비게이션 화면으로 이동
      if (routeProvider.routes.isNotEmpty && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NavigationDetailsScreen(
              startLat: startLat,
              startLon: startLon,
              endLat: endLat,
              endLon: endLon,
              startName: startName,
              endName: endName,
              transportMode: transportMode,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('경로 탐색 실패: $e')),
        );
      }
    }
  }

  Widget _buildTransportOption(
      BuildContext context,
      IconData icon,
      String label,
      Color color,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _navigateToTransportMode(
      BuildContext context,
      app_route.Route route,
      RouteSegment segment,
      String transportMode,
      ) {
    Navigator.pop(context); // 바텀시트 닫기

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationDetailsScreen(
          startLat: segment.startLat,
          startLon: segment.startLon,
          endLat: segment.endLat,
          endLon: segment.endLon,
          startName: segment.startLocation,
          endName: segment.endLocation,
          transportMode: transportMode,
        ),
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
                        onTap: () {
                          // 경로 선택 시 바로 첫 번째 세그먼트로 내비게이션 시작
                          if (route.segments.isNotEmpty) {
                            final segment = route.segments[0];
                            // 직접 내비게이션 화면으로 이동
                            _startDirectNavigation(
                                context,
                                segment.startLat,
                                segment.startLon,
                                segment.endLat,
                                segment.endLon,
                                route.transportMode, // 이미 선택된 이동 수단 사용
                                segment.startLocation,
                                segment.endLocation
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('경로 정보가 없습니다.')),
                            );
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
                                    // 이동 수단 표시 추가
                                    Text(
                                      _getTransportModeText(route.transportMode),
                                      style: TextStyle(
                                        color: _getTransportModeColor(route.transportMode),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.navigation, color: Colors.blue),
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

// 3. 이동 수단 표시용 헬퍼 메서드 추가
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

  Color _getTransportModeColor(String transportMode) {
    switch (transportMode.toUpperCase()) {
      case 'WALK':
        return Colors.green;
      case 'TRANSIT':
        return Colors.blue;
      case 'DRIVING':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}