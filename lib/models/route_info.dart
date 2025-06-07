// lib/models/route_info.dart - 상세 정보가 포함된 RouteInfo 모델

import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteInfo {
  final List<LatLng> points;
  final String distance;
  final String duration;
  final List<LatLng> samplePoints;
  final String description;     // 🆕 경로 상세 설명
  final String routeType;       // 🆕 경로 타입 (API 출처 등)
  final String? fare;           // 🆕 요금 정보
  final int? transferCount;     // 🆕 환승 횟수 (대중교통)
  final int? walkingMinutes;    // 🆕 도보 시간 (대중교통)
  final List<String>? lines;    // 🆕 이용 노선 (대중교통)
  final double? avgSpeed;       // 🆕 평균 속도
  final int? estimatedCost;     // 🆕 예상 비용 (연료비 등)
  final int? calories;          // 🆕 소모 칼로리 (도보)
  final Map<String, dynamic>? additionalInfo; // 🆕 추가 정보

  RouteInfo({
    required this.points,
    required this.distance,
    required this.duration,
    required this.samplePoints,
    this.description = '',
    this.routeType = 'normal',
    this.fare,
    this.transferCount,
    this.walkingMinutes,
    this.lines,
    this.avgSpeed,
    this.estimatedCost,
    this.calories,
    this.additionalInfo,
  });

  // 🆕 상세 정보를 포함한 생성자
  RouteInfo.withDetails({
    required this.points,
    required this.distance,
    required this.duration,
    required this.samplePoints,
    required this.description,
    required this.routeType,
    this.fare,
    this.transferCount,
    this.walkingMinutes,
    this.lines,
    this.avgSpeed,
    this.estimatedCost,
    this.calories,
    this.additionalInfo,
  });

  // 🆕 대중교통 전용 생성자
  RouteInfo.transit({
    required this.points,
    required this.distance,
    required this.duration,
    required this.samplePoints,
    required this.description,
    required this.fare,
    required this.transferCount,
    required this.walkingMinutes,
    required this.lines,
    this.routeType = 'transit',
    this.avgSpeed,
    this.estimatedCost,
    this.calories,
    this.additionalInfo,
  });

  // 🆕 자동차 전용 생성자
  RouteInfo.driving({
    required this.points,
    required this.distance,
    required this.duration,
    required this.samplePoints,
    required this.description,
    required this.avgSpeed,
    required this.estimatedCost,
    this.routeType = 'driving',
    this.fare,
    this.transferCount,
    this.walkingMinutes,
    this.lines,
    this.calories,
    this.additionalInfo,
  });

  // 🆕 도보 전용 생성자
  RouteInfo.walking({
    required this.points,
    required this.distance,
    required this.duration,
    required this.samplePoints,
    required this.description,
    required this.calories,
    this.routeType = 'walking',
    this.fare,
    this.transferCount,
    this.walkingMinutes,
    this.lines,
    this.avgSpeed,
    this.estimatedCost,
    this.additionalInfo,
  });

  // 🆕 복사 메서드
  RouteInfo copyWith({
    List<LatLng>? points,
    String? distance,
    String? duration,
    List<LatLng>? samplePoints,
    String? description,
    String? routeType,
    String? fare,
    int? transferCount,
    int? walkingMinutes,
    List<String>? lines,
    double? avgSpeed,
    int? estimatedCost,
    int? calories,
    Map<String, dynamic>? additionalInfo,
  }) {
    return RouteInfo(
      points: points ?? this.points,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      samplePoints: samplePoints ?? this.samplePoints,
      description: description ?? this.description,
      routeType: routeType ?? this.routeType,
      fare: fare ?? this.fare,
      transferCount: transferCount ?? this.transferCount,
      walkingMinutes: walkingMinutes ?? this.walkingMinutes,
      lines: lines ?? this.lines,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      calories: calories ?? this.calories,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  // 🆕 JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'distance': distance,
      'duration': duration,
      'description': description,
      'routeType': routeType,
      'fare': fare,
      'transferCount': transferCount,
      'walkingMinutes': walkingMinutes,
      'lines': lines,
      'avgSpeed': avgSpeed,
      'estimatedCost': estimatedCost,
      'calories': calories,
      'additionalInfo': additionalInfo,
    };
  }

  // 🆕 디버그용 문자열
  @override
  String toString() {
    return 'RouteInfo(distance: $distance, duration: $duration, description: $description, routeType: $routeType)';
  }
}