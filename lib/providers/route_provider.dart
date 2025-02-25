// lib/providers/route_provider.dart
import '../../models/route.dart' as app_route;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/route.dart' as route_model;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_helper/models/place_info.dart';
import 'package:trip_helper/models/route_analysis.dart';
import 'package:trip_helper/models/route_segment.dart';
import '../models/route.dart';
import 'dart:ui' as ui;

class RouteProvider with ChangeNotifier {
  List<route_model.Route> _routes = [];
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';
  route_model.Route? _selectedRoute;
  route_model.Route? get selectedRoute => _selectedRoute;
  List<route_model.Route> get routes => _routes;
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  // 상수로 경로 색상 정의
  static const List<Color> routeColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
  ];
  // 마커 생성
// route_provider.dart

// createMarkers 메서드를 async로 변경
  Future<Set<Marker>> createMarkers() async {
    Set<Marker> markers = {};

    for (int i = 0; i < _routes.length + 1; i++) {
      try {
        LatLng position;
        String title;
        String snippet;

        if (i == 0) {
          position = LatLng(
              _routes.first.segments.first.startLat,
              _routes.first.segments.first.startLon
          );
          title = _routes.first.segments.first.startLocation;
          snippet = "출발";
        } else if (i == _routes.length) {
          position = LatLng(
              _routes.last.segments.last.endLat,
              _routes.last.segments.last.endLon
          );
          title = _routes.last.segments.last.endLocation;
          snippet = "도착";
        } else {
          position = LatLng(
              _routes[i].segments.first.startLat,
              _routes[i].segments.first.startLon
          );
          title = _routes[i].segments.first.startLocation;
          snippet = "${i + 1}번째 경유지";
        }

        final markerIcon = await _createCustomMarkerBitmap(
            number: i + 1,
            isStart: i == 0,
            isEnd: i == _routes.length
        );

        markers.add(
          Marker(
            markerId: MarkerId('spot_$i'),
            position: position,
            icon: markerIcon,
            infoWindow: InfoWindow(
              title: title,
              snippet: snippet,
            ),
          ),
        );
      } catch (e) {
        print('Error creating marker $i: $e');
      }
    }

    return markers;
  }
// 커스텀 마커 비트맵 생성 메서드
  Future<BitmapDescriptor> _createCustomMarkerBitmap({
    required int number,
    bool isStart = false,
    bool isEnd = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(80, 80);

    final paint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    // 원형 배경 그리기
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      30,
      paint,
    );

    // 테두리 그리기
    final borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      30,
      borderPaint,
    );

    // 텍스트 그리기
    final String markerText = isStart ? 'S' : (isEnd ? 'E' : number.toString());
    final textPainter = TextPainter(
      text: TextSpan(
        text: markerText,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: isStart || isEnd ? Colors.red : Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // 경로 라인 생성
  Set<Polyline> createPolylines() {
    print('Creating polylines for ${_routes.length} routes'); // 디버깅용
    Set<Polyline> polylines = {};
    final colors = [Colors.green, Colors.pink, Colors.purple];

    for (int i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      List<LatLng> points = [];

      for (var segment in route.segments) {
        points.add(LatLng(segment.startLat, segment.startLon));
        points.add(LatLng(segment.endLat, segment.endLon));
      }

      polylines.add(
        Polyline(
          polylineId: PolylineId('route_$i'),
          points: points,
          color: colors[i % colors.length],
          width: 5,
        ),
      );
    }
    print('Created ${polylines.length} polylines'); // 디버깅용
    return polylines;
  }

  Future<void> getRecommendedRoutes(List<Map<String, dynamic>> schedules) async {
    try {
      _isLoading = true;
      _error = null;
      _routes = [];
      notifyListeners();

      print('Received schedules: $schedules'); // 디버깅용

      // 좌표값 검증
      if (schedules.isEmpty) {
        throw Exception('일정 데이터가 없습니다.');
      }

      // 각 일정의 좌표값 확인
      for (var schedule in schedules) {
        if (schedule['type'] == 'FIXED' &&
            (schedule['latitude'] == null || schedule['longitude'] == null)) {
          print('Invalid schedule data: $schedule'); // 디버깅용
          throw Exception('위치 정보가 없는 일정이 있습니다.');
        }
      }

      // 1. 유연한 일정이 있는 경우, 주변 장소 검색
      List<Map<String, dynamic>> flexibleSchedules =
      schedules.where((s) => s['type'] == 'FLEXIBLE').toList();

      if (flexibleSchedules.isNotEmpty) {
        for (var schedule in flexibleSchedules) {
          try {
            // 가장 가까운 고정 일정 찾기
            var nearestFixed = _findNearestFixedSchedule(schedules, schedule);

            if (nearestFixed != null) {
              final response = await http.get(
                Uri.parse(
                    '$baseUrl/places/nearby?lat=${nearestFixed['latitude']}&lon=${nearestFixed['longitude']}&type=${schedule['name']}&radius=1000'
                ),
              );

              if (response.statusCode == 200) {
                var places = json.decode(response.body)['places'];
                schedule['nearbyPlaces'] = places;
              }
            }
          } catch (e) {
            print('Error fetching nearby places: $e');
          }
        }
      }

      // 2. 경로 최적화 API 호출
      final response = await http.post(
        Uri.parse('$baseUrl/schedules/optimize-flexible'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fixedSchedules': schedules.where((s) => s['type'] == 'FIXED').toList(),
          'flexibleSchedules': flexibleSchedules,
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> routesData = json.decode(response.body)['routes'];
        _routes = routesData.map((routeData) => app_route.Route.fromJson(routeData)).toList();
      } else {
        throw Exception('Failed to optimize routes');
      }

      _isLoading = false;
      notifyListeners();

    } catch (e, stackTrace) {
      print('Error in getRecommendedRoutes: $e');
      print('Stack trace: $stackTrace');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? _findNearestFixedSchedule(
      List<Map<String, dynamic>> allSchedules,
      Map<String, dynamic> flexibleSchedule
      ) {
    var fixedSchedules = allSchedules.where((s) => s['type'] == 'FIXED').toList();
    if (fixedSchedules.isEmpty) return null;

    return fixedSchedules[0]; // 임시로 첫 번째 고정 일정 반환
  }

  Future<List<Map<String, dynamic>>> _fetchNearbyPlaces(
      String placeType,
      double lat,
      double lon,
      ) async {
    final response = await http.get(
      Uri.parse(
          '$baseUrl/places/nearby?lat=$lat&lon=$lon&type=$placeType&radius=1000'
      ),
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(
          json.decode(response.body)['places']
      );
    } else {
      throw Exception('Failed to fetch nearby places');
    }
  }
  double _parseCoordinate(dynamic value) {
    try {
      if (value is int) {
        return value / 10000000.0;
      } else if (value is double) {
        return value;
      } else if (value is String) {
        return double.parse(value);
      }
      throw Exception('Invalid coordinate format: $value');
    } catch (e) {
      print('Error parsing coordinate: $value');
      throw Exception('Invalid coordinate format: $value');
    }
  }


  int _calculateTotalDuration(List<RouteSegment> segments) {
    return segments.fold(0, (sum, segment) => sum + segment.duration);
  }

  double _calculateTotalDistance(List<RouteSegment> segments) {
    return segments.fold(0.0, (sum, segment) => sum + segment.distance);
  }

  double _calculateTotalCost(List<RouteSegment> segments) {
    return segments.fold(0.0, (sum, segment) {
      switch (segment.transportMode.toUpperCase()) {
        case 'TAXI':
          return sum + (3800 + (segment.distance * 1000));
        case 'BUS':
          return sum + 1200;
        case 'SUBWAY':
          return sum + 1350;
        default:
          return sum;
      }
    });
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw Exception('로그인이 필요합니다.');
    }
    return 'Bearer $token';
  }


  void selectRoute(route_model.Route route) {
    _selectedRoute = route;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> updateLocation(double lat, double lon, {double? speed, double? heading}) async {
    try {
      final token = await _getToken();
      final navigationId = _selectedRoute?.id;

      if (navigationId == null) {
        throw Exception('No navigation session active');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/navigation/$navigationId/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
        body: json.encode({
          'latitude': lat,
          'longitude': lon,
          'speed': speed,
          'heading': heading,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['status'] == 'COMPLETED') {
          _selectedRoute = null;
        }
        notifyListeners();
      } else if (response.statusCode == 403) {
        throw Exception('인증이 필요합니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 404) {
        throw Exception('내비게이션 세션을 찾을 수 없습니다.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update location');
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> startNavigation(double lat, double lon) async {
    try {
      final token = await _getToken();

      if (_selectedRoute == null) {
        throw Exception('No route selected');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/navigation/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
        body: json.encode({
          'routeId': _selectedRoute!.id,
          'currentLocation': {
            'latitude': lat,
            'longitude': lon,
          },
        }),
      );

      if (response.statusCode == 200) {
        notifyListeners();
      } else {
        throw Exception('Failed to start navigation');
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopNavigation() async {
    try {
      if (_selectedRoute == null) return;

      final token = await _getToken();
      final navigationId = _selectedRoute!.id;

      final response = await http.delete(
        Uri.parse('$baseUrl/navigation/$navigationId'),
        headers: {
          'Authorization': token,
        },
      );

      if (response.statusCode == 200) {
        _selectedRoute = null;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}