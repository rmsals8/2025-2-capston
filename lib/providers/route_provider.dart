// lib/providers/route_provider.dart
import '../../models/route.dart' as app_route;
import 'dart:math';
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

      print('Received schedules: $schedules');

      // 좌표가 유효한지 확인
      bool hasValidCoordinates = schedules.any((schedule) {
        double lat = schedule['latitude'] ?? 0.0;
        double lng = schedule['longitude'] ?? 0.0;
        return lat != 0.0 && lng != 0.0;
      });

      if (!hasValidCoordinates) {
        _error = '유효한 위치 정보가 없습니다.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      try {
        // 서버 API 호출 시도
        Map<String, dynamic> requestBody = {
          'fixedSchedules': schedules.map((s) => {
            'id': s['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'name': s['name'],
            'type': 'FIXED',
            'duration': _extractDurationMinutes(s['duration']),
            'priority': s['priority'] ?? 1,
            'location': s['location'],
            'latitude': s['latitude'],
            'longitude': s['longitude'],
            'startTime': s['visitTime'],
            'endTime': _calculateEndTime(s['visitTime'], s['duration']),
          }).toList(),
          'flexibleSchedules': [] // 빈 배열 사용
        };

        final response = await http.post(
          Uri.parse('$baseUrl/schedules/optimize-1'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        );

        // 서버 응답 처리 시도
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['optimizedSchedules'] != null && data['optimizedSchedules'].isNotEmpty) {
            // 서버 응답 사용하기
            print('서버 응답으로 경로 생성 시도');
          } else {
            print('서버 응답에 최적화된 일정이 없습니다.');
          }
        }
      } catch (serverError) {
        print('서버 API 호출 오류, 클라이언트에서 경로 생성: $serverError');
      }

      // 서버 호출 성공 여부와 관계없이 직접 경로 생성
      print('클라이언트에서 직접 경로 생성');
      _createDirectRoutes(schedules);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error in getRecommendedRoutes: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

// 직접 경로 생성 메서드
  void _createDirectRoutes(List<Map<String, dynamic>> schedules) {
    _routes = [];

    if (schedules.length < 2) {
      print('경로 생성을 위한 충분한 일정이 없습니다.');
      return;
    }

    // 일정을 시간 순으로 정렬
    schedules.sort((a, b) {
      DateTime timeA = DateTime.parse(a['visitTime'] ?? DateTime.now().toIso8601String());
      DateTime timeB = DateTime.parse(b['visitTime'] ?? DateTime.now().toIso8601String());
      return timeA.compareTo(timeB);
    });

    // 각 일정 간 경로 생성
    for (int i = 0; i < schedules.length - 1; i++) {
      final current = schedules[i];
      final next = schedules[i + 1];

      // 경로 세그먼트 생성
      RouteSegment segment = RouteSegment(
        id: 'segment_$i',
        startLocation: current['name'] ?? '출발지',
        endLocation: next['name'] ?? '도착지',
        startLat: current['latitude'] ?? 0.0,
        startLon: current['longitude'] ?? 0.0,
        endLat: next['latitude'] ?? 0.0,
        endLon: next['longitude'] ?? 0.0,
        duration: 30, // 기본 30분
        distance: 5.0, // 기본 5km
        instruction: '${current['name'] ?? '출발지'}에서 ${next['name'] ?? '도착지'}으로 이동',
        transportMode: 'WALK', // 기본 도보
      );

      // 경로 생성 및 추가
      _routes.add(app_route.Route(
        id: 'route_$i',
        segments: [segment],
        totalDuration: 30,
        totalDistance: 5.0,
        totalCost: 0.0,
        transportMode: 'WALK',
        congestionLevel: 0.3,
        summary: '${current['name'] ?? '출발지'}에서 ${next['name'] ?? '도착지'}으로 이동',
      ));
    }

    print('Created ${_routes.length} routes');
  }

// 시간 문자열에서 분 추출
  int _extractDurationMinutes(dynamic duration) {
    if (duration == null) return 60;

    if (duration is int) return duration;

    String durationStr = duration.toString();
    try {
      if (durationStr.startsWith('PT')) {
        // ISO 8601 형식 (PT1H30M)
        durationStr = durationStr.substring(2);
        int minutes = 0;

        if (durationStr.contains('H')) {
          int hourIndex = durationStr.indexOf('H');
          int hours = int.parse(durationStr.substring(0, hourIndex));
          minutes += hours * 60;
          durationStr = durationStr.substring(hourIndex + 1);
        }

        if (durationStr.contains('M')) {
          int minuteIndex = durationStr.indexOf('M');
          int mins = int.parse(durationStr.substring(0, minuteIndex));
          minutes += mins;
        }

        return minutes;
      } else {
        // 단순 숫자로 된 경우
        return int.parse(durationStr);
      }
    } catch (e) {
      return 60; // 기본값
    }
  }

// 시작 시간과 시간 문자열에서 종료 시간 계산
  String _calculateEndTime(dynamic startTime, dynamic duration) {
    if (startTime == null) return DateTime.now().toIso8601String();

    try {
      DateTime start = DateTime.parse(startTime.toString());
      int minutes = _extractDurationMinutes(duration);
      return start.add(Duration(minutes: minutes)).toIso8601String();
    } catch (e) {
      return DateTime.now().add(Duration(hours: 1)).toIso8601String();
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


  // lib/providers/route_provider.dart에 추가할 메서드

// route_provider.dart 파일에 추가할 좌표 변환 함수

// 좌표값 정규화 (큰 숫자를 올바른 좌표 범위로 변환)
  double _normalizeCoordinate(double value, bool isLatitude) {
    // 정상 범위 확인
    final double minValue = isLatitude ? -90.0 : -180.0;
    final double maxValue = isLatitude ? 90.0 : 180.0;

    // 이미 올바른 범위에 있는 경우 그대로 반환
    if (value >= minValue && value <= maxValue) {
      return value;
    }

    // 큰 숫자를 가진 좌표는 변환 필요
    // 예: 한국 국가 지점 번호(National Points) 또는 네이버 지도 좌표로 보임

    // 방법 1: 숫자 크기에 따른 자동 변환
    if (value.abs() > 1000000) {
      // 숫자가 매우 큰 경우 (예: 355437482.0 -> 35.5437482)
      // 소수점 위치를 7자리 이동
      return value / 10000000.0;
    } else if (value.abs() > 100000) {
      // 숫자가 큰 경우 (예: 35543748.0 -> 35.543748)
      // 소수점 위치를 6자리 이동
      return value / 1000000.0;
    } else if (value.abs() > 10000) {
      // 중간 크기 (예: 3554374.0 -> 35.54374)
      // 소수점 위치를 5자리 이동
      return value / 100000.0;
    } else if (value.abs() > 1000) {
      // 더 작은 중간 크기 (예: 355437.0 -> 35.5437)
      // 소수점 위치를 4자리 이동
      return value / 10000.0;
    } else if (value.abs() > 180) {
      // 작은 숫자 (예: 355.0 -> 35.5)
      // 소수점 위치를 1자리 이동
      return value / 10.0;
    }

    // 다른 방법으로도 해결이 안 되면 한국 영역의 일반적인 좌표로 대체
    if (isLatitude) {
      return 35.5384;  // 기본 위도
    } else {
      return 129.3114; // 기본 경도
    }
  }

// route_provider.dart 파일의 getDirectionsWithGoogleApi 메서드 수정
  Future<void> getDirectionsWithGoogleApi(
      double startLat,
      double startLng,
      double endLat,
      double endLng,
      String transportMode
      ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 좌표 정규화 (추가된 부분)
      final normalizedStartLat = _normalizeCoordinate(startLat, true);
      final normalizedStartLng = _normalizeCoordinate(startLng, false);
      final normalizedEndLat = _normalizeCoordinate(endLat, true);
      final normalizedEndLng = _normalizeCoordinate(endLng, false);

      print('API 요청 전 좌표 정규화:');
      print('원본 출발지: $startLat, $startLng → 변환: $normalizedStartLat, $normalizedStartLng');
      print('원본 도착지: $endLat, $endLng → 변환: $normalizedEndLat, $normalizedEndLng');

      final String apiKey = 'AIzaSyA036NtD7ALG40jOnqSGks2QsI1nAG9cGI';
      final String mode = _getGoogleApiMode(transportMode);

      // 요청 URL 구성 - 정규화된 좌표 사용
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?'
              'origin=${normalizedStartLat.toStringAsFixed(6)},${normalizedStartLng.toStringAsFixed(6)}'
              '&destination=${normalizedEndLat.toStringAsFixed(6)},${normalizedEndLng.toStringAsFixed(6)}'
              '&mode=$mode'
              '&language=ko'
              '&alternatives=true'
              '&key=$apiKey'
      );

      print('요청 URL: $url');

      final response = await http.get(url);
      print('응답 상태 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)); // UTF-8 디코딩 추가
        print('응답 상태: ${data['status']}');

        if (data['status'] == 'OK') {
          // 경로 데이터 파싱
          final routes = await _parseGoogleDirectionsResponse(data, transportMode);
          _routes = routes;
          print('경로를 성공적으로 찾았습니다. ${routes.length}개의 경로가 있습니다.');
        } else if (data['status'] == 'ZERO_RESULTS') {
          print('경로를 찾을 수 없습니다.');
          _error = '해당 이동 수단으로 경로를 찾을 수 없습니다. 다른 이동 수단을 선택해 보세요.';
          _routes = [_createDirectRoute(normalizedStartLat, normalizedStartLng, normalizedEndLat, normalizedEndLng, transportMode)];
        } else {
          print('API 오류: ${data['status']}');
          _error = '경로 검색 실패: ${data['status']}';
          _routes = [_createDirectRoute(normalizedStartLat, normalizedStartLng, normalizedEndLat, normalizedEndLng, transportMode)];
        }
      } else {
        print('네트워크 오류: ${response.statusCode}');
        _error = '네트워크 요청 실패: ${response.statusCode}';
        _routes = [_createDirectRoute(normalizedStartLat, normalizedStartLng, normalizedEndLat, normalizedEndLng, transportMode)];
      }
    } catch (e) {
      print('예외 발생: $e');
      _error = '경로 검색 중 오류가 발생했습니다: $e';
      _routes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

// 직선 경로 생성 메서드 추가
// 직선 경로 생성 메서드도 수정
  app_route.Route _createDirectRoute(
      double startLat,
      double startLng,
      double endLat,
      double endLng,
      String transportMode
      ) {
    print('직선 경로 생성');

    // 거리 계산
    final double distance = _calculateDistance(startLat, startLng, endLat, endLng);

    // 시간 계산 (교통 수단에 따라 다름)
    int duration;
    if (transportMode == 'WALK') {
      duration = (distance * 12).round(); // 도보는 km당 약 12분
    } else if (transportMode == 'TRANSIT') {
      duration = (distance * 3).round(); // 대중교통은 km당 약 3분
    } else {
      duration = (distance * 1.5).round(); // 자동차는 km당 약 1.5분
    }

    // 비용 계산
    double cost;
    if (transportMode == 'TRANSIT') {
      cost = 1350.0; // 기본 요금
    } else if (transportMode == 'DRIVING') {
      cost = 4800.0 + (distance * 2000); // 기본 요금 + 거리별 요금
    } else {
      cost = 0.0;
    }

    // 간단한 세그먼트 생성
    final segment = RouteSegment(
      id: 'direct',
      startLocation: '출발지',
      endLocation: '도착지',
      startLat: startLat,
      startLon: startLng,
      endLat: endLat,
      endLon: endLng,
      duration: duration,
      distance: distance,
      instruction: '직선 경로로 이동합니다',
      transportMode: transportMode, // 이동 수단 보존
    );

    return app_route.Route(
      id: 'direct_route',
      segments: [segment],
      totalDuration: duration,
      totalDistance: distance,
      totalCost: cost,
      transportMode: transportMode, // 이동 수단 보존
      congestionLevel: 0.0,
      summary: '직선 경로',
    );
  }

// 하버사인 공식을 사용한 두 지점 간 거리 계산
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // 지구 반지름 (km)
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
            cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
                sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  String _getGoogleApiMode(String transportMode) {
    switch (transportMode.toUpperCase()) {
      case 'WALK':
        return 'walking';
      case 'TRANSIT':
        return 'transit';
      case 'DRIVING':
      default:
        return 'driving';
    }
  }


// _parseGoogleDirectionsResponse 메서드 수정
  Future<List<app_route.Route>> _parseGoogleDirectionsResponse(Map<String, dynamic> data, String transportMode) async {
    List<app_route.Route> routes = [];

    for (int routeIndex = 0; routeIndex < data['routes'].length; routeIndex++) {
      final route = data['routes'][routeIndex];
      final legs = route['legs'];

      for (int legIndex = 0; legIndex < legs.length; legIndex++) {
        final leg = legs[legIndex];
        final steps = leg['steps'];

        List<RouteSegment> segments = [];

        for (int j = 0; j < steps.length; j++) {
          final step = steps[j];
          final startLocation = step['start_location'];
          final endLocation = step['end_location'];

          // HTML 태그 제거
          String instruction = step['html_instructions'] ?? '이동';
          instruction = instruction.replaceAll(RegExp(r'<[^>]*>'), ' ');

          // 여기서 단계별 이동 수단을 파악
          String segmentMode = step['travel_mode'] ?? transportMode;

          segments.add(
            RouteSegment(
              id: 'segment_${routeIndex}_${legIndex}_$j',
              startLocation: j == 0 ? leg['start_address'] : '경유지',
              endLocation: j == steps.length - 1 ? leg['end_address'] : '경유지',
              startLat: startLocation['lat'],
              startLon: startLocation['lng'],
              endLat: endLocation['lat'],
              endLon: endLocation['lng'],
              duration: (step['duration']['value'] / 60).round(),
              distance: step['distance']['value'] / 1000,
              instruction: instruction,
              transportMode: segmentMode,
            ),
          );
        }

        // 경로가 없는 경우 추가
        if (segments.isEmpty) {
          continue;
        }

        // 총 소요시간, 거리 계산
        final totalDuration = (leg['duration']['value'] / 60).round();
        final totalDistance = leg['distance']['value'] / 1000;

        // 요약 정보
        String summary = route['summary'] ?? '';
        if (summary.isEmpty) {
          summary = '${leg['start_address']} → ${leg['end_address']}';
        }

        routes.add(
          app_route.Route(
            id: 'route_${routeIndex}_$legIndex',
            segments: segments,
            totalDuration: totalDuration,
            totalDistance: totalDistance,
            totalCost: _calculateCost(totalDistance, transportMode),
            transportMode: transportMode, // 여기서 전체 경로의 이동 수단 설정
            congestionLevel: 0.2, // 기본값
            summary: summary,
          ),
        );
      }
    }

    return routes;
  }
  double _calculateCost(double distance, String transportMode) {
    switch (transportMode.toUpperCase()) {
      case 'TRANSIT':
        return 1350.0; // 기본 대중교통 요금
      case 'DRIVING':
        return 4800.0 + (distance * 2000); // 기본 택시 요금 + 거리별 요금
      case 'WALK':
      default:
        return 0.0;
    }
  }
}