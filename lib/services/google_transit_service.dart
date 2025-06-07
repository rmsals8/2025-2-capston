import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../models/route_info.dart';

class GoogleTransitRoute {
  final List<LatLng> points;
  final String distance;
  final String duration;
  final String summary;
  final List<TransitStep> steps;
  final String totalFare;

  GoogleTransitRoute({
    required this.points,
    required this.distance,
    required this.duration,
    required this.summary,
    required this.steps,
    required this.totalFare,
  });
}

class TransitStep {
  final String instruction;
  final String mode; // WALKING, TRANSIT
  final String? transitLine; // 버스/지하철 노선명
  final String? transitType; // BUS, SUBWAY, TRAIN
  final String? departureStop;
  final String? arrivalStop;
  final String? departureTime;
  final String? arrivalTime;
  final String duration;
  final String distance;
  final String? lineColor;
  // ✅ 실제 정류장 좌표 추가
  final LatLng? departureStopLocation;
  final LatLng? arrivalStopLocation;

  TransitStep({
    required this.instruction,
    required this.mode,
    this.transitLine,
    this.transitType,
    this.departureStop,
    this.arrivalStop,
    this.departureTime,
    this.arrivalTime,
    required this.duration,
    required this.distance,
    this.lineColor,
    this.departureStopLocation, // ✅ 추가
    this.arrivalStopLocation,   // ✅ 추가
  });
}

class GoogleTransitService {
  final String? apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
  final PolylinePoints polylinePoints = PolylinePoints();

  Future<List<GoogleTransitRoute>> getTransitRoutes(
      LatLng origin,
      LatLng destination,
      {DateTime? departureTime}
      ) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('Google Maps API key not found');
    }

    // 현재 시간 또는 지정된 시간
    final time = departureTime ?? DateTime.now();
    final departureTimestamp = time.millisecondsSinceEpoch ~/ 1000;

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=${origin.latitude},${origin.longitude}'
            '&destination=${destination.latitude},${destination.longitude}'
            '&mode=transit'
            '&departure_time=$departureTimestamp'
            '&alternatives=true'
            '&language=ko'
            '&region=kr'
            '&key=$apiKey'
    );

    print('🚌 Google 대중교통 API 호출: $url');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print('📡 Google 대중교통 응답 상태: ${data['status']}');

        if (data['status'] == 'OK') {
          final routes = data['routes'] as List;
          print('✅ 찾은 대중교통 경로 수: ${routes.length}');

          return routes.map((route) => _parseGoogleTransitRoute(route)).toList();
        } else if (data['status'] == 'ZERO_RESULTS') {
          print('⚠️ 대중교통 경로를 찾을 수 없습니다');
          return [];
        } else {
          print('❌ Google API 오류: ${data['status']} - ${data['error_message'] ?? ''}');
          throw Exception('Google Directions API error: ${data['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Google 대중교통 검색 오류: $e');
      rethrow;
    }
  }

  GoogleTransitRoute _parseGoogleTransitRoute(Map<String, dynamic> route) {
    final leg = route['legs'][0];
    final steps = leg['steps'] as List;

    // 전체 경로 폴리라인 디코딩
    List<LatLng> allPoints = [];
    if (route['overview_polyline'] != null) {
      final encodedPolyline = route['overview_polyline']['points'];
      allPoints = polylinePoints
          .decodePolyline(encodedPolyline)
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    }

    // 단계별 파싱 (정류장 좌표 포함)
    List<TransitStep> transitSteps = [];
    String totalFare = '';

    for (var step in steps) {
      final travelMode = step['travel_mode'];

      if (travelMode == 'WALKING') {
        transitSteps.add(TransitStep(
          instruction: _cleanHtmlTags(step['html_instructions'] ?? ''),
          mode: 'WALKING',
          duration: step['duration']['text'],
          distance: step['distance']['text'],
        ));
      } else if (travelMode == 'TRANSIT') {
        final transitDetails = step['transit_details'];
        final line = transitDetails['line'];

        // 요금 정보
        if (transitDetails['fare'] != null) {
          totalFare = transitDetails['fare']['text'] ?? '';
        }

        // ✅ 정류장 좌표 추출
        LatLng? departureStopLocation;
        LatLng? arrivalStopLocation;

        if (transitDetails['departure_stop'] != null &&
            transitDetails['departure_stop']['location'] != null) {
          final depLocation = transitDetails['departure_stop']['location'];
          departureStopLocation = LatLng(
            depLocation['lat'].toDouble(),
            depLocation['lng'].toDouble(),
          );
          print('✅ 출발 정류장 좌표: ${transitDetails['departure_stop']['name']} - $departureStopLocation');
        }

        if (transitDetails['arrival_stop'] != null &&
            transitDetails['arrival_stop']['location'] != null) {
          final arrLocation = transitDetails['arrival_stop']['location'];
          arrivalStopLocation = LatLng(
            arrLocation['lat'].toDouble(),
            arrLocation['lng'].toDouble(),
          );
          print('✅ 도착 정류장 좌표: ${transitDetails['arrival_stop']['name']} - $arrivalStopLocation');
        }

        transitSteps.add(TransitStep(
          instruction: _cleanHtmlTags(step['html_instructions'] ?? ''),
          mode: 'TRANSIT',
          transitLine: line['short_name'] ?? line['name'],
          transitType: line['vehicle']['type'], // BUS, SUBWAY, etc.
          departureStop: transitDetails['departure_stop']['name'],
          arrivalStop: transitDetails['arrival_stop']['name'],
          departureTime: transitDetails['departure_time']['text'],
          arrivalTime: transitDetails['arrival_time']['text'],
          duration: step['duration']['text'],
          distance: step['distance']['text'],
          lineColor: line['color'],
          departureStopLocation: departureStopLocation, // ✅ 실제 좌표
          arrivalStopLocation: arrivalStopLocation,     // ✅ 실제 좌표
        ));
      }
    }

    // 요약 정보 생성
    String summary = _generateRouteSummary(transitSteps);

    return GoogleTransitRoute(
      points: allPoints,
      distance: leg['distance']['text'],
      duration: leg['duration']['text'],
      summary: summary,
      steps: transitSteps,
      totalFare: totalFare,
    );
  }

  String _generateRouteSummary(List<TransitStep> steps) {
    List<String> transitParts = [];

    for (var step in steps) {
      if (step.mode == 'TRANSIT') {
        String part = '';

        // 교통수단 아이콘
        switch (step.transitType?.toLowerCase()) {
          case 'subway':
            part += '🚇 ';
            break;
          case 'bus':
            part += '🚌 ';
            break;
          case 'train':
            part += '🚄 ';
            break;
          default:
            part += '🚌 ';
        }

        part += step.transitLine ?? '';
        transitParts.add(part);
      }
    }

    return transitParts.join(' → ');
  }

  String _cleanHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
  }

  // RouteInfo로 변환 (기존 시스템과 호환)
  List<RouteInfo> convertToRouteInfo(List<GoogleTransitRoute> transitRoutes) {
    return transitRoutes.map((transitRoute) {
      return RouteInfo(
        points: transitRoute.points,
        distance: transitRoute.distance,
        duration: transitRoute.duration,
        samplePoints: _getSamplePoints(transitRoute.points),
      );
    }).toList();
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
}