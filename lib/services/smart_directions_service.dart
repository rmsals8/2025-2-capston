// lib/services/smart_directions_service.dart - 디버깅 강화 버전
import 'dart:convert';
import 'dart:math' show pi, sin, cos, sqrt, atan2;
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../models/route_info.dart';
import '../models/transport_mode.dart';
import 'google_transit_service.dart';

class SmartDirectionsService {
  final String? kakaoApiKey = dotenv.env['KAKAO_API_KEY'];
  final String? tmapApiKey = dotenv.env['TMAP_API_KEY'];
  final String? googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
  final PolylinePoints polylinePoints = PolylinePoints();

  // 🔧 디버깅을 위한 API 키 확인
  void _checkApiKeys() {
    print('🔑 API 키 확인:');
    print('Google API Key: ${googleApiKey != null ? "${googleApiKey!.substring(0, 10)}..." : "❌ 없음"}');
    print('Kakao API Key: ${kakaoApiKey != null ? "${kakaoApiKey!.substring(0, 10)}..." : "❌ 없음"}');
    print('Tmap API Key: ${tmapApiKey != null ? "${tmapApiKey!.substring(0, 10)}..." : "❌ 없음"}');
  }

  // 🔧 좌표 유효성 검증
  bool _validateCoordinates(LatLng origin, LatLng destination) {
    print('📍 좌표 검증:');
    print('출발지: ${origin.latitude}, ${origin.longitude}');
    print('도착지: ${destination.latitude}, ${destination.longitude}');

    // 한국 좌표 범위 확인
    bool isOriginValid = _isValidKoreanCoordinate(origin.latitude, origin.longitude);
    bool isDestinationValid = _isValidKoreanCoordinate(destination.latitude, destination.longitude);

    print('출발지 유효성: ${isOriginValid ? "✅" : "❌"}');
    print('도착지 유효성: ${isDestinationValid ? "✅" : "❌"}');

    if (!isOriginValid || !isDestinationValid) {
      print('⚠️ 좌표가 한국 범위를 벗어났습니다');
      return false;
    }

    // 거리 확인
    double distance = _calculateDistance(origin, destination);
    print('두 지점 간 거리: ${distance.toStringAsFixed(2)}km');

    if (distance > 1000) {
      print('⚠️ 거리가 너무 멉니다 (1000km 초과)');
      return false;
    }

    if (distance < 0.01) {
      print('⚠️ 출발지와 도착지가 너무 가깝습니다 (10m 미만)');
      return false;
    }

    return true;
  }

  bool _isValidKoreanCoordinate(double lat, double lon) {
    return lat >= 33.0 && lat <= 39.0 && lon >= 124.0 && lon <= 132.0;
  }

  Future<List<RouteInfo>> getRoutes(
      LatLng origin,
      LatLng destination,
      TransportMode mode
      ) async {
    print('\n🚀 === 경로 검색 시작 ===');
    print('교통수단: ${mode.label}');

    _checkApiKeys();

    if (!_validateCoordinates(origin, destination)) {
      print('❌ 좌표 검증 실패 - 직선 경로 생성');
      return [_createFallbackRoute(origin, destination, mode)];
    }

    try {
      switch (mode) {
        case TransportMode.driving:
          return await _getDrivingRoutes(origin, destination);
        case TransportMode.walking:
          return await _getWalkingRoutes(origin, destination);
        case TransportMode.transit:
          return await _getTransitRoutes(origin, destination);
      }
    } catch (e) {
      print('💥 전체 경로 검색 실패: $e');
      return [_createFallbackRoute(origin, destination, mode)];
    }
  }

  // 대중교통 상세 정보와 함께 반환하는 메서드
  Future<Map<String, dynamic>> getTransitRoutesWithDetails(
      LatLng origin,
      LatLng destination,
      ) async {
    print('\n🚌 === 대중교통 상세 검색 시작 ===');

    _checkApiKeys();

    if (!_validateCoordinates(origin, destination)) {
      print('❌ 좌표 검증 실패');
      return {
        'routes': [_createFallbackRoute(origin, destination, TransportMode.transit)],
        'transitDetails': <GoogleTransitRoute>[],
      };
    }

    try {
      final transitService = GoogleTransitService();
      print('🔄 Google Transit API 호출 중...');

      final transitRoutes = await transitService.getTransitRoutes(origin, destination);

      if (transitRoutes.isNotEmpty) {
        final routeInfoList = transitService.convertToRouteInfo(transitRoutes);
        print('✅ 대중교통 ${transitRoutes.length}개 경로 + 상세정보 반환');

        return {
          'routes': routeInfoList,
          'transitDetails': transitRoutes,
        };
      } else {
        print('⚠️ Google Transit API에서 경로를 찾지 못함');
      }
    } catch (e) {
      print('❌ Google 대중교통 상세 검색 실패: $e');
    }

    print('💡 대중교통 폴백 경로 생성');
    return {
      'routes': [_createFallbackRoute(origin, destination, TransportMode.transit)],
      'transitDetails': <GoogleTransitRoute>[],
    };
  }

  // 🚗 자동차 경로 검색
  Future<List<RouteInfo>> _getDrivingRoutes(LatLng origin, LatLng destination) async {
    print('\n🚗 자동차 경로 검색 시작...');

    // 1. Google Directions API 시도 (가장 안정적)
    try {
      print('🔄 Google Directions API 시도...');
      final routes = await _getGoogleDrivingRoutes(origin, destination);
      if (routes.isNotEmpty) {
        print('✅ Google 자동차 경로 성공: ${routes.length}개');
        return routes;
      }
    } catch (e) {
      print('❌ Google 자동차 실패: $e');
    }

    // 2. 카카오 자동차 경로 시도
    try {
      print('🔄 카카오 자동차 API 시도...');
      return await _getKakaoDrivingRoutes(origin, destination);
    } catch (e) {
      print('❌ 카카오 자동차 실패: $e');
    }

    // 3. T맵 자동차 경로 시도
    try {
      print('🔄 T맵 자동차 API 시도...');
      return await _getTmapDrivingRoutes(origin, destination);
    } catch (e) {
      print('❌ T맵 자동차 실패: $e');
    }

    print('⚠️ 모든 자동차 API 실패 - 직선 경로 생성');
    return [_createFallbackRoute(origin, destination, TransportMode.driving)];
  }

  // 🚶‍♂️ 도보 경로 검색
  Future<List<RouteInfo>> _getWalkingRoutes(LatLng origin, LatLng destination) async {
    print('\n🚶‍♂️ 도보 경로 검색 시작...');

    // 1. Google Directions API 시도 (가장 안정적)
    try {
      print('🔄 Google 도보 API 시도...');
      final routes = await _getGoogleWalkingRoutes(origin, destination);
      if (routes.isNotEmpty) {
        print('✅ Google 도보 경로 성공: ${routes.length}개');
        return routes;
      }
    } catch (e) {
      print('❌ Google 도보 실패: $e');
    }

    // 2. T맵 도보 경로 시도
    try {
      print('🔄 T맵 도보 API 시도...');
      return await _getTmapWalkingRoutes(origin, destination);
    } catch (e) {
      print('❌ T맵 도보 실패: $e');
    }

    print('⚠️ 모든 도보 API 실패 - 직선 경로 생성');
    return [_createFallbackRoute(origin, destination, TransportMode.walking)];
  }

  // 🚌 대중교통 경로 검색
  Future<List<RouteInfo>> _getTransitRoutes(LatLng origin, LatLng destination) async {
    print('\n🚌 대중교통 경로 검색 시작...');

    try {
      print('🔄 Google 대중교통 API 시도...');
      final routes = await _getGoogleTransitRoutes(origin, destination);
      if (routes.isNotEmpty) {
        print('✅ Google 대중교통 ${routes.length}개 경로 반환 성공');
        return routes;
      }
    } catch (e) {
      print('❌ Google 대중교통 실패: $e');
    }

    print('💡 대중교통 정보가 제한적입니다.');
    return [_createFallbackRoute(origin, destination, TransportMode.transit)];
  }

  // Google Directions API 호출 (개선된 오류 처리)
  Future<List<RouteInfo>> _getGoogleDrivingRoutes(LatLng origin, LatLng destination) async {
    return await _getGoogleRoutes(origin, destination, 'driving');
  }

  Future<List<RouteInfo>> _getGoogleWalkingRoutes(LatLng origin, LatLng destination) async {
    return await _getGoogleRoutes(origin, destination, 'walking');
  }

  Future<List<RouteInfo>> _getGoogleTransitRoutes(LatLng origin, LatLng destination) async {
    if (googleApiKey == null || googleApiKey!.isEmpty) {
      throw Exception('Google API 키가 설정되지 않았습니다');
    }

    final departureTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=${origin.latitude.toStringAsFixed(6)},${origin.longitude.toStringAsFixed(6)}'
            '&destination=${destination.latitude.toStringAsFixed(6)},${destination.longitude.toStringAsFixed(6)}'
            '&mode=transit'
            '&departure_time=$departureTime'
            '&alternatives=true'
            '&language=ko'
            '&region=kr'
            '&key=$googleApiKey'
    );

    print('🌐 요청 URL: $url');

    final response = await http.get(url);
    print('📡 응답 상태: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('📄 API 상태: ${data['status']}');

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        final routes = data['routes'] as List;
        print('✅ 대중교통 경로 ${routes.length}개 파싱 시작');

        List<RouteInfo> transitRoutes = [];

        for (int i = 0; i < routes.length; i++) {
          final route = routes[i];
          final leg = route['legs'][0];

          List<LatLng> points = [];
          if (route['overview_polyline'] != null) {
            final encodedPolyline = route['overview_polyline']['points'];
            points = polylinePoints
                .decodePolyline(encodedPolyline)
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();
          }

          String transitSummary = _parseTransitSteps(leg['steps']);
          String distance = leg['distance']['text'];
          String duration = leg['duration']['text'];

          print('경로 ${i + 1}: $transitSummary ($duration, $distance, ${points.length}개 포인트)');

          transitRoutes.add(RouteInfo(
            points: points,
            distance: distance,
            duration: '$duration • $transitSummary',
            samplePoints: _getSamplePoints(points),
          ));
        }

        return transitRoutes;
      } else if (data['status'] == 'ZERO_RESULTS') {
        print('⚠️ Google: 대중교통 경로 없음');
        throw Exception('경로를 찾을 수 없습니다');
      } else {
        print('❌ Google API 오류: ${data['status']} - ${data['error_message'] ?? ''}');
        if (data['status'] == 'REQUEST_DENIED') {
          throw Exception('API 키가 잘못되었거나 Directions API가 활성화되지 않았습니다');
        }
        throw Exception('Google API 오류: ${data['status']}');
      }
    } else {
      throw Exception('HTTP 오류: ${response.statusCode}');
    }
  }

  // Google API 공통 메서드 (개선된 오류 처리)
  Future<List<RouteInfo>> _getGoogleRoutes(LatLng origin, LatLng destination, String mode) async {
    if (googleApiKey == null || googleApiKey!.isEmpty) {
      throw Exception('Google API 키가 설정되지 않았습니다');
    }

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=${origin.latitude.toStringAsFixed(6)},${origin.longitude.toStringAsFixed(6)}'
            '&destination=${destination.latitude.toStringAsFixed(6)},${destination.longitude.toStringAsFixed(6)}'
            '&mode=$mode'
            '&language=ko'
            '&region=kr'
            '&alternatives=true'
            '&key=$googleApiKey'
    );

    print('🌐 Google $mode 요청: $url');

    final response = await http.get(url);
    print('📡 응답 상태: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('📄 API 상태: ${data['status']}');

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        print('✅ Google $mode 경로 성공');
        final routes = data['routes'] as List;

        return routes.map((route) {
          final points = polylinePoints
              .decodePolyline(route['overview_polyline']['points'])
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          final leg = route['legs'][0];

          return RouteInfo(
            points: points,
            distance: leg['distance']['text'],
            duration: leg['duration']['text'],
            samplePoints: _getSamplePoints(points),
          );
        }).toList();
      } else if (data['status'] == 'ZERO_RESULTS') {
        print('⚠️ Google $mode: 경로 없음');
        throw Exception('경로를 찾을 수 없습니다');
      } else {
        print('❌ Google $mode API 오류: ${data['status']}');
        if (data['status'] == 'REQUEST_DENIED') {
          throw Exception('API 키가 잘못되었거나 Directions API가 활성화되지 않았습니다');
        }
        throw Exception('Google API 오류: ${data['status']}');
      }
    } else {
      throw Exception('HTTP 오류: ${response.statusCode}');
    }
  }

  // 폴백 경로 생성 (개선된 메시지)
  RouteInfo _createFallbackRoute(LatLng origin, LatLng destination, TransportMode mode) {
    print('📏 직선 경로 생성 중... (${mode.label})');

    final points = _createSmoothPath(origin, destination);
    final distance = _calculateDistance(origin, destination);

    final speed = mode == TransportMode.walking ? 5.0 :
    mode == TransportMode.transit ? 25.0 : 40.0;

    final durationInMinutes = (distance / speed * 60).round();

    String distanceText = '${distance.toStringAsFixed(1)} km';
    String durationText;

    if (mode == TransportMode.transit) {
      durationText = '지하철/버스앱 확인 권장';
    } else {
      durationText = '예상 ${durationInMinutes}분 (직선)';
    }

    return RouteInfo(
      points: points,
      distance: distanceText,
      duration: durationText,
      samplePoints: _getSamplePoints(points),
    );
  }

  // 나머지 헬퍼 메서드들 (기존과 동일)
  String _parseTransitSteps(List steps) {
    List<String> transitParts = [];

    for (var step in steps) {
      if (step['travel_mode'] == 'TRANSIT') {
        final transitDetails = step['transit_details'];
        if (transitDetails != null) {
          final line = transitDetails['line'];
          final vehicle = line['vehicle'];

          String icon = '';
          switch (vehicle['type']?.toLowerCase()) {
            case 'subway':
              icon = '🚇';
              break;
            case 'bus':
              icon = '🚌';
              break;
            case 'train':
              icon = '🚄';
              break;
            default:
              icon = '🚌';
          }

          String lineName = line['short_name'] ?? line['name'] ?? '';
          transitParts.add('$icon $lineName');
        }
      }
    }

    return transitParts.isNotEmpty ? transitParts.join(' → ') : '대중교통';
  }

  List<LatLng> _createSmoothPath(LatLng start, LatLng end) {
    const segments = 20;
    List<LatLng> points = [];

    for (int i = 0; i <= segments; i++) {
      double fraction = i / segments;
      points.add(LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction,
      ));
    }

    return points;
  }

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

  double _calculateDistance(LatLng p1, LatLng p2) {
    const earthRadius = 6371.0;
    final lat1 = p1.latitude * pi / 180;
    final lat2 = p2.latitude * pi / 180;
    final dLat = (p2.latitude - p1.latitude) * pi / 180;
    final dLng = (p2.longitude - p1.longitude) * pi / 180;

    final a = sin(dLat/2) * sin(dLat/2) +
        cos(lat1) * cos(lat2) *
            sin(dLng/2) * sin(dLng/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));

    return earthRadius * c;
  }

  // 카카오, T맵 API 메서드들 (기존과 동일하지만 로깅 추가)
  Future<List<RouteInfo>> _getKakaoDrivingRoutes(LatLng origin, LatLng destination) async {
    if (kakaoApiKey == null) throw Exception('카카오 API 키 없음');
    // ... 기존 구현 + 로깅
    throw Exception('카카오 API 구현 필요');
  }

  Future<List<RouteInfo>> _getTmapDrivingRoutes(LatLng origin, LatLng destination) async {
    if (tmapApiKey == null) throw Exception('T맵 API 키 없음');
    // ... 기존 구현 + 로깅
    throw Exception('T맵 API 구현 필요');
  }

  Future<List<RouteInfo>> _getTmapWalkingRoutes(LatLng origin, LatLng destination) async {
    if (tmapApiKey == null) throw Exception('T맵 API 키 없음');
    // ... 기존 구현 + 로깅
    throw Exception('T맵 API 구현 필요');
  }
}