// lib/models/route_info.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteInfo {
  final List<LatLng> points;  // 경로의 모든 점들
  final String distance;      // 거리 (문자열 형식, 예: "5.2km")
  final String duration;      // 소요 시간 (문자열 형식, 예: "15분")
  final List<LatLng> samplePoints;  // 경로의 주요 샘플 포인트 (검색에 사용)

  RouteInfo({
    required this.points,
    required this.distance,
    required this.duration,
    required this.samplePoints,
  });
}