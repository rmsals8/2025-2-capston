// lib/screens/route/optimized_routes_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/route_info.dart';
import '../../models/schedule.dart';
import '../../models/route.dart' as app_route;
import '../../providers/route_provider.dart';
import '../../widgets/map/route_map.dart';
import '../../widgets/route/route_card.dart';
import '../navigation/navigation_screen.dart';
import 'dart:math' as math;

class OptimizedRoutesScreen extends StatefulWidget {
  final List<Schedule> fixedSchedules;
  final List<Map<String, dynamic>> flexibleSchedules;

  const OptimizedRoutesScreen({
    Key? key,
    required this.fixedSchedules,
    required this.flexibleSchedules,
  }) : super(key: key);

  @override
  State<OptimizedRoutesScreen> createState() => _OptimizedRoutesScreenState();
}

class _OptimizedRoutesScreenState extends State<OptimizedRoutesScreen> {
  int _selectedRouteIndex = 0;
  late final RouteProvider _routeProvider;

  @override
  void initState() {
    super.initState();
    _routeProvider = Provider.of<RouteProvider>(context, listen: false);
    _optimizeRoutes();
  }

  Future<void> _optimizeRoutes() async {
    try {
      await _routeProvider.getRecommendedRoutes(widget.flexibleSchedules);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('경로 최적화 실패: $e')),
      );
    }
  }

  // 🔧 선택된 경로에서 출발지와 도착지 추출
  LatLng _getRouteStartLocation(app_route.Route route) {
    if (route.segments.isNotEmpty) {
      final firstSegment = route.segments.first;
      return LatLng(firstSegment.startLat, firstSegment.startLon);
    }

    // 폴백: 첫 번째 스케줄의 위치 사용
    if (widget.fixedSchedules.isNotEmpty) {
      final firstSchedule = widget.fixedSchedules.first;
      return LatLng(firstSchedule.latitude, firstSchedule.longitude);
    }

    // 최종 폴백: 서울시청 좌표
    return LatLng(37.5666103, 126.9783882);
  }

  LatLng _getRouteEndLocation(app_route.Route route) {
    if (route.segments.isNotEmpty) {
      final lastSegment = route.segments.last;
      return LatLng(lastSegment.endLat, lastSegment.endLon);
    }

    // 폴백: 마지막 스케줄의 위치 사용
    if (widget.fixedSchedules.isNotEmpty) {
      final lastSchedule = widget.fixedSchedules.last;
      return LatLng(lastSchedule.latitude, lastSchedule.longitude);
    }

    // 최종 폴백: 강남역 좌표
    return LatLng(37.4979, 127.0276);
  }

  // 🔧 app_route.Route를 RouteInfo로 변환
  RouteInfo _convertRouteToRouteInfo(app_route.Route route) {
    // 경로의 모든 좌표점 추출
    List<LatLng> points = [];
    for (var segment in route.segments) {
      points.add(LatLng(segment.startLat, segment.startLon));
      points.add(LatLng(segment.endLat, segment.endLon));
    }

    // 중복 제거
    List<LatLng> uniquePoints = [];
    for (var point in points) {
      if (uniquePoints.isEmpty ||
          (uniquePoints.last.latitude != point.latitude ||
              uniquePoints.last.longitude != point.longitude)) {
        uniquePoints.add(point);
      }
    }

    return RouteInfo(
      points: uniquePoints.isNotEmpty ? uniquePoints : [
        _getRouteStartLocation(route),
        _getRouteEndLocation(route)
      ],
      distance: '${route.totalDistance.toStringAsFixed(1)} km',
      duration: '${route.totalDuration}분',
      samplePoints: uniquePoints.isNotEmpty ? _getSamplePoints(uniquePoints) : [
        _getRouteStartLocation(route),
        _getRouteEndLocation(route)
      ],
    );
  }

  // 🔧 샘플 포인트 생성
  List<LatLng> _getSamplePoints(List<LatLng> points) {
    if (points.length <= 2) return points;

    List<LatLng> samples = [];
    int step = (points.length / 5).round();
    if (step < 1) step = 1;

    for (int i = 0; i < points.length; i += step) {
      samples.add(points[i]);
    }

    if (!samples.contains(points.last)) {
      samples.add(points.last);
    }

    return samples;
  }

  RouteInfo _createRouteInfo(LatLng start, LatLng end) {
    final distance = _calculateDistance(start, end);
    final estimatedTime = _calculateEstimatedTime(start, end);

    return RouteInfo(
      points: [start, end],
      distance: '${distance.toStringAsFixed(1)} km',
      duration: '예상 ${estimatedTime.round()}분',
      samplePoints: [start, end],
    );
  }

  double _calculateEstimatedTime(LatLng start, LatLng end) {
    final distance = _calculateDistance(start, end);
    return (distance / 40) * 60; // 40km/h 기준, 분 단위
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // 지구 반지름 (km)

    final double lat1Rad = start.latitude * (math.pi / 180);
    final double lat2Rad = end.latitude * (math.pi / 180);
    final double dLatRad = (end.latitude - start.latitude) * (math.pi / 180);
    final double dLngRad = (end.longitude - start.longitude) * (math.pi / 180);

    final double a = math.pow(math.sin(dLatRad / 2), 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
            math.pow(math.sin(dLngRad / 2), 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('최적화된 경로'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Consumer<RouteProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('경로 최적화 중...'),
                ],
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text('오류: ${provider.error}'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _optimizeRoutes,
                    child: Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          final routes = provider.routes;
          if (routes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('가능한 경로가 없습니다.'),
                ],
              ),
            );
          }

          return Column(
            children: [
              // 지도 표시
              Expanded(
                flex: 1,
                child: RouteMap(
                  routes: routes,
                  selectedRoute: routes[_selectedRouteIndex],
                  onRouteSelected: (route) {
                    setState(() {
                      _selectedRouteIndex = routes.indexOf(route);
                    });
                  },
                ),
              ),

              // 경로 옵션 목록
              Expanded(
                flex: 1,
                child: ListView.builder(
                  itemCount: routes.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final route = routes[index];
                    final startLocation = _getRouteStartLocation(route);
                    final endLocation = _getRouteEndLocation(route);

                    return RouteCard(
                      route: route,
                      isSelected: index == _selectedRouteIndex,
                      onTap: () {
                        setState(() {
                          _selectedRouteIndex = index;
                        });
                      },
                      onStartNavigation: () {
                        // 🔧 올바른 NavigationScreen 호출
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NavigationScreen(
                              route: _convertRouteToRouteInfo(route), // ✅ 실제 경로 데이터 사용
                              origin: startLocation,     // ✅ 경로에서 추출한 출발지
                              destination: endLocation,  // ✅ 경로에서 추출한 도착지
                              transportMode: route.transportMode.toLowerCase(), // ✅ 경로의 교통수단
                              transitRoute: null,        // ✅ 대중교통 정보 (없음)
                            ),
                          ),
                        );
                      },
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
}