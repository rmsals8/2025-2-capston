import 'package:flutter/foundation.dart';

class RouteSegment {
  final String id;
  final String startLocation;
  final String endLocation;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final int duration; // 소요시간(분)
  final double distance; // 거리(km)
  final String instruction; // 안내 메시지
  final String transportMode; // WALK, CAR, TRANSIT

  RouteSegment({
    required this.id,
    required this.startLocation,
    required this.endLocation,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.duration,
    required this.distance,
    required this.instruction,
    required this.transportMode,
  });

  factory RouteSegment.fromJson(Map<String, dynamic> json) {
    return RouteSegment(
      id: json['id'] as String,
      startLocation: json['startLocation'] as String,
      endLocation: json['endLocation'] as String,
      startLat: (json['startLat'] as num).toDouble(),
      startLon: (json['startLon'] as num).toDouble(),
      endLat: (json['endLat'] as num).toDouble(),
      endLon: (json['endLon'] as num).toDouble(),
      duration: json['duration'] as int,
      distance: (json['distance'] as num).toDouble(),
      instruction: json['instruction'] as String,
      transportMode: json['transportMode'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startLocation': startLocation,
      'endLocation': endLocation,
      'startLat': startLat,
      'startLon': startLon,
      'endLat': endLat,
      'endLon': endLon,
      'duration': duration,
      'distance': distance,
      'instruction': instruction,
      'transportMode': transportMode,
    };
  }
}