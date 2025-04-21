// lib/utils/route_converter.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route.dart' as app_route;
import '../models/route_info.dart';

class RouteConverter {
  // app_route.Route 객체를 RouteInfo 객체로 변환
  static RouteInfo convertToRouteInfo(app_route.Route route) {
    // 모든 경로 포인트 추출
    List<LatLng> allPoints = [];
    for (var segment in route.segments) {
      allPoints.add(LatLng(segment.startLat, segment.startLon));
      allPoints.add(LatLng(segment.endLat, segment.endLon));
    }

    // 중복 제거 (같은 점이 여러 번 나올 수 있음)
    List<LatLng> uniquePoints = [];
    for (var point in allPoints) {
      if (!uniquePoints.contains(point)) {
        uniquePoints.add(point);
      }
    }

    // 샘플 포인트 생성 (시작, 중간, 끝 포인트와 몇 개의 추가 포인트)
    List<LatLng> samplePoints = _createSamplePoints(uniquePoints);

    return RouteInfo(
      points: uniquePoints,
      distance: '${route.totalDistance.toStringAsFixed(1)}km',
      duration: '${route.totalDuration}분',
      samplePoints: samplePoints,
    );
  }

  // 샘플 포인트 생성 (경로 검색에 사용할 대표 포인트들)
  static List<LatLng> _createSamplePoints(List<LatLng> points) {
    if (points.isEmpty) return [];
    if (points.length <= 3) return List.from(points);

    // 최소 5개의 샘플 포인트 생성 (시작, 끝, 중간 점들)
    List<LatLng> samples = [];

    // 시작점 추가
    samples.add(points.first);

    // 중간 포인트들 추가 (균등하게 분포)
    int step = (points.length / 3).ceil();
    for (int i = step; i < points.length - step; i += step) {
      samples.add(points[i]);
    }

    // 끝점 추가
    samples.add(points.last);

    return samples;
  }
}