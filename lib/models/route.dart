import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'route_segment.dart';

class Route {
  final String id;
  final List<RouteSegment> segments;
  final int totalDuration; // 총 소요시간(분)
  final double totalDistance; // 총 거리(km)
  final double totalCost; // 총 비용(원)
  final String transportMode; // WALK, CAR, TRANSIT
  final double congestionLevel; // 0.0 ~ 1.0
  final String summary; // 경로 요약 설명

  Color get routeColor {
    switch (transportMode.toLowerCase()) {
      case 'walk':
        return Colors.green;
      case 'car':
        return Colors.blue;
      case 'transit':
        return Colors.orange;
      case 'taxi':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // estimatedCost getter 추가
  double get estimatedCost => totalCost;

  // duration getter 추가
  int get duration => totalDuration;

  // distance getter 추가
  double get distance => totalDistance;

  Route({
    required this.id,
    required this.segments,
    required this.totalDuration,
    required this.totalDistance,
    required this.totalCost,
    required this.transportMode,
    required this.congestionLevel,
    this.summary = '',
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      id: json['id'] as String,
      segments: (json['segments'] as List)
          .map((segment) => RouteSegment.fromJson(segment))
          .toList(),
      totalDuration: json['totalDuration'] as int,
      totalDistance: (json['totalDistance'] as num).toDouble(),
      totalCost: (json['totalCost'] as num).toDouble(),
      transportMode: json['transportMode'] as String,
      congestionLevel: (json['congestionLevel'] as num).toDouble(),
      summary: json['summary'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'segments': segments.map((segment) => segment.toJson()).toList(),
      'totalDuration': totalDuration,
      'totalDistance': totalDistance,
      'totalCost': totalCost,
      'transportMode': transportMode,
      'congestionLevel': congestionLevel,
      'summary': summary,
    };
  }
}