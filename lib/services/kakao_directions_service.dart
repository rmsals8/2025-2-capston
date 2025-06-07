import 'dart:convert';
import 'dart:math' show pi, sin, cos, sqrt, atan2;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_info.dart';

class KakaoDirectionsService {
  final String? kakaoApiKey = dotenv.env['KAKAO_API_KEY']; // REST API 키

  Future<List<RouteInfo>> getRoutes(LatLng origin, LatLng destination) async {
    print('🥕 카카오 API Key: ${kakaoApiKey?.substring(0, 10)}...' ?? 'NULL');

    if (kakaoApiKey == null || kakaoApiKey!.isEmpty) {
      print('❌ 카카오 API 키가 없습니다!');
      throw Exception('Kakao API key not found');
    }

    // 카카오 길찾기 API (자동차)
    final url = Uri.parse('https://apis-navi.kakaomobility.com/v1/directions');

    final requestBody = {
      'origin': {
        'x': origin.longitude,
        'y': origin.latitude
      },
      'destination': {
        'x': destination.longitude,
        'y': destination.latitude
      },
      'waypoints': [], // 경유지 없음
      'priority': 'RECOMMEND', // 추천 경로
      'car_fuel': 'GASOLINE',
      'car_hipass': false,
      'alternatives': true, // 대안 경로 요청
      'road_details': true // 상세 도로 정보
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'KakaoAK $kakaoApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('📡 카카오 응답 상태: ${response.statusCode}');
      print('📄 응답 본문: ${response.body.substring(0, 500)}...');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final routes = data['routes'] as List;
          print('✅ 카카오에서 찾은 경로 수: ${routes.length}');

          return routes.map((route) => _parseKakaoRoute(route)).toList();
        }
      } else if (response.statusCode == 401) {
        print('❌ 카카오 API 인증 실패');
      } else if (response.statusCode == 400) {
        print('❌ 잘못된 요청 파라미터');
      }

      // 카카오 실패 시 T맵 시도
      return await _tryTmapRoutes(origin, destination);

    } catch (e) {
      print('💥 카카오 API 예외: $e');
      return await _tryTmapRoutes(origin, destination);
    }
  }

  RouteInfo _parseKakaoRoute(Map<String, dynamic> route) {
    final summary = route['summary'];
    final sections = route['sections'] as List;

    List<LatLng> points = [];

    // 각 섹션의 도로 좌표 추출
    for (var section in sections) {
      if (section['roads'] != null) {
        for (var road in section['roads']) {
          if (road['vertexes'] != null) {
            final vertexes = road['vertexes'] as List;
            // vertexes는 [lng, lat, lng, lat, ...] 형태
            for (int i = 0; i < vertexes.length; i += 2) {
              if (i + 1 < vertexes.length) {
                points.add(LatLng(
                  vertexes[i + 1].toDouble(), // lat
                  vertexes[i].toDouble(),     // lng
                ));
              }
            }
          }
        }
      }
    }

    print('📍 카카오 파싱된 포인트 수: ${points.length}');

    return RouteInfo(
      points: points,
      distance: '${(summary['distance'] / 1000).toStringAsFixed(1)} km',
      duration: '${(summary['duration'] / 60).round()}분',
      samplePoints: _getSamplePoints(points),
    );
  }

  // T맵 API 시도 (백업)
  Future<List<RouteInfo>> _tryTmapRoutes(LatLng origin, LatLng destination) async {
    final tmapApiKey = dotenv.env['TMAP_API_KEY'];

    if (tmapApiKey == null || tmapApiKey.isEmpty) {
      print('⚠️ T맵 API 키도 없음 - 직선 경로 생성');
      return [_createStraightRoute(origin, destination)];
    }

    print('🚗 T맵 API 시도...');

    final url = Uri.parse('https://apis.openapi.sk.com/tmap/routes/pedestrian');

    try {
      final response = await http.post(
        url,
        headers: {
          'appKey': tmapApiKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'startX': origin.longitude.toString(),
          'startY': origin.latitude.toString(),
          'endX': destination.longitude.toString(),
          'endY': destination.latitude.toString(),
          'reqCoordType': 'WGS84GEO',
          'resCoordType': 'WGS84GEO',
          'startName': '출발지',
          'endName': '목적지'
        }),
      );

      print('📡 T맵 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return [_parseTmapRoute(data)];
      }

    } catch (e) {
      print('💥 T맵 API 예외: $e');
    }

    print('⚠️ 모든 API 실패 - 직선 경로 생성');
    return [_createStraightRoute(origin, destination)];
  }

  RouteInfo _parseTmapRoute(Map<String, dynamic> data) {
    final features = data['features'] as List;
    List<LatLng> points = [];
    double totalDistance = 0;
    double totalTime = 0; // int에서 double로 변경

    for (var feature in features) {
      final geometry = feature['geometry'];
      final properties = feature['properties'];

      if (geometry['type'] == 'LineString') {
        final coordinates = geometry['coordinates'] as List;
        for (var coord in coordinates) {
          points.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
        }
      }

      if (properties != null) {
        totalDistance += (properties['distance'] ?? 0).toDouble();
        totalTime += (properties['time'] ?? 0).toDouble(); // toDouble()로 변경
      }
    }

    print('📍 T맵 파싱된 포인트 수: ${points.length}');

    return RouteInfo(
      points: points,
      distance: '${(totalDistance / 1000).toStringAsFixed(1)} km',
      duration: '${(totalTime / 60).round()}분', // round() 추가
      samplePoints: _getSamplePoints(points),
    );
  }

  RouteInfo _createStraightRoute(LatLng origin, LatLng destination) {
    print('📏 직선 경로 생성 중...');

    final points = _createSmoothPath(origin, destination);
    final distance = _calculateDistance(origin, destination);
    final durationInMinutes = (distance / 1000 / 40 * 60).round();

    return RouteInfo(
      points: points,
      distance: '${(distance / 1000).toStringAsFixed(1)} km (직선)',
      duration: '$durationInMinutes분 (예상)',
      samplePoints: _getSamplePoints(points),
    );
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
    const earthRadius = 6371000.0;
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
}