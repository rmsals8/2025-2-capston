// lib/screens/route/route_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/route_segment.dart';
import '../../providers/route_provider.dart';
import '../../providers/navigation_provider.dart';
import '../navigation/navigation_screen.dart';
import '../navigation/navigation_details_screen.dart';
import '../../models/route.dart' as app_route;
import 'dart:math';
import '../place_recommendations_screen.dart';
import '../../services/location_service.dart';
import '../../services/place_recommendation_service.dart';
import '../../models/route_info.dart';
import '../../utils/route_converter.dart';

class RouteListScreen extends StatefulWidget {
  const RouteListScreen({Key? key}) : super(key: key);

  @override
  State<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends State<RouteListScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  int _selectedRouteIndex = 0; // 선택된 경로 인덱스
  final LocationService _locationService = LocationService(); // 위치 서비스 인스턴스 추가

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
            // 경로 주변 장소 추천 버튼 추가
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _showNearbyPlaces(context, startLat, startLon, endLat, endLon);
                  },
                  child: const Text('경로 주변 장소 추천'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 주변 장소 추천 기능 구현
  void _showNearbyPlaces(BuildContext context, double startLat, double startLon, double endLat, double endLon) async {
    try {
      Navigator.pop(context); // 현재 바텀시트 닫기

      // 로딩 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주변 장소를 검색 중입니다...')),
      );

      // 현재 위치 가져오기 (출발지로 사용)
      LatLng currentLocation;
      try {
        final position = await _locationService.getCurrentLocation();
        currentLocation = LatLng(position.latitude, position.longitude);
      } catch (e) {
        // 현재 위치를 가져올 수 없는 경우 출발지 좌표 사용
        currentLocation = LatLng(startLat, startLon);
      }

      // 경로 중간점 계산 (시각화를 위한 중심점)
      final centerLat = (startLat + endLat) / 2;
      final centerLng = (startLon + endLon) / 2;
      final centerLocation = LatLng(centerLat, centerLng);

      // 장소 추천 화면으로 이동
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaceRecommendationsScreen(
              currentLocation: currentLocation,
              title: '경로 주변 추천 장소',
              route: null, // RouteInfo가 아니라서 경로 주변 추천은 동작하지 않음
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('장소 추천을 불러올 수 없습니다: $e')),
        );
      }
    }
  }

  // 내비게이션 직접 시작 메서드 (수정)
  void _startDirectNavigation(BuildContext context, double startLat, double startLon, double endLat, double endLon, String transportMode, String startName, String endName) {
    try {
      // 좌표 검증
      if (startLat < -90 || startLat > 90 ||
          endLat < -90 || endLat > 90 ||
          startLon < -180 || startLon > 180 ||
          endLon < -180 || endLon > 180) {
        throw Exception('유효하지 않은 좌표입니다.');
      }

      // 내비게이션 화면으로 이동
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내비게이션을 시작할 수 없습니다: $e')),
      );
    }
  }

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
        actions: [
          // 방문 기록 보기 버튼
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // 방문 기록 화면으로 이동 (해당 화면이 구현되어 있다면)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Scaffold(
                    body: Center(
                      child: Text('방문 기록 화면이 곧 구현될 예정입니다.'),
                    ),
                  ),
                ),
              );
            },
            tooltip: '방문 기록',
          )
        ],
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
                      elevation: index == _selectedRouteIndex ? 4 : 1,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedRouteIndex = index;
                          });

                          // 경로 선택 시 해당 경로 강조
                          _updateRouteHighlight(routeProvider.routes, index);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                ],
                              ),
                              const SizedBox(height: 12),
                              // 버튼 추가
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // 경로 주변 장소 추천 버튼
                                  TextButton.icon(
                                    onPressed: () {
                                      if (route.segments.isNotEmpty) {
                                        _showPlacesAlongRoute(context, route);
                                      }
                                    },
                                    icon: const Icon(Icons.place, size: 18),
                                    label: const Text('주변 장소'),
                                  ),
                                  const SizedBox(width: 8),
                                  // 내비게이션 시작 버튼
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      if (route.segments.isNotEmpty) {
                                        final segment = route.segments[0];
                                        _startDirectNavigation(
                                            context,
                                            segment.startLat,
                                            segment.startLon,
                                            segment.endLat,
                                            segment.endLon,
                                            route.transportMode,
                                            segment.startLocation,
                                            segment.endLocation
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.navigation, size: 18),
                                    label: const Text('길안내'),
                                  ),
                                ],
                              ),
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

  // 경로 선택 시 시각적으로 강조
  void _updateRouteHighlight(List<app_route.Route> routes, int selectedIndex) {
    final colors = [Colors.blue.withOpacity(0.5), Colors.red.withOpacity(0.5), Colors.green.withOpacity(0.5)];
    final selectedColors = [Colors.blue, Colors.red, Colors.green];

    setState(() {
      _polylines.clear();

      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];
        if (route.segments.isEmpty) continue;

        List<LatLng> points = [];
        for (var segment in route.segments) {
          points.add(LatLng(segment.startLat, segment.startLon));
          points.add(LatLng(segment.endLat, segment.endLon));
        }

        // 선택된 경로는 진한 색상과 두꺼운 선, 나머지는 옅은 색상과 얇은 선
        _polylines.add(Polyline(
          polylineId: PolylineId('route_$i'),
          points: points,
          color: i == selectedIndex ? selectedColors[i % selectedColors.length] : colors[i % colors.length],
          width: i == selectedIndex ? 7 : 3,
        ));
      }
    });
  }

  // 경로 주변 장소 추천 다이얼로그 표시
  void _showPlacesAlongRoute(BuildContext context, app_route.Route route) async {
    try {
      if (route.segments.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('경로 정보가 없습니다')),
        );
        return;
      }

      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text("경로 주변 장소를 검색 중입니다..."),
                ],
              ),
            ),
          );
        },
      );

      // 경로 정보 가져오기
      final currentLocation = LatLng(
          route.segments.first.startLat,
          route.segments.first.startLon
      );

      // app_route.Route를 RouteInfo로 변환
      final routeInfo = RouteConverter.convertToRouteInfo(route);

      print('경로 변환: ${routeInfo.points.length}개 포인트, ${routeInfo.samplePoints.length}개 샘플 포인트');

      // 경로 주변 장소 검색
      final recommendationService = PlaceRecommendationService();
      final places = await recommendationService.getPlacesAlongRoute(
        routeInfo,
        radius: 1000, // 경로에서 1km 이내
      );

      print('경로 주변 추천 장소 수: ${places.length}');

      // 로딩 다이얼로그 닫기
      if (context.mounted) {
        Navigator.pop(context);
      }

      // 결과가 없는 경우
      if (places.isEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('경로 주변에 추천할 장소가 없습니다')),
        );
        return;
      }

      // 장소 추천 화면으로 이동
      if (context.mounted) {
        final startName = route.segments.first.startLocation;
        final endName = route.segments.last.endLocation;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaceRecommendationsScreen(
              currentLocation: currentLocation,
              title: '$startName → $endName 주변 추천',
              route: routeInfo,
            ),
          ),
        );
      }
    } catch (e) {
      // 로딩 다이얼로그가 열려 있으면 닫기
      if (context.mounted) {
        Navigator.pop(context);

        // 오류 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('장소 추천을 불러올 수 없습니다: $e')),
        );
      }
    }
  }

  // 이동 수단 텍스트 변환
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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}