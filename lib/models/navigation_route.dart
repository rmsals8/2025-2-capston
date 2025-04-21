// lib/models/navigation_route.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

// class NavigationRoute {
//   final String id;
//   final List<LatLng> points;
//   final String transportMode;
//   final int duration;
//   final double distance;
//   final Color color;
//
//   NavigationRoute({
//     required this.id,
//     required this.points,
//     required this.transportMode,
//     required this.duration,
//     required this.distance,
//     this.color = Colors.blue,
//   });
//
//   factory NavigationRoute.fromJson(Map<String, dynamic> json, Color color) {
//     return NavigationRoute(
//       id: json['segmentId'] ?? '',
//       points: (json['path'] as List<dynamic>?)?.map((point) => LatLng(
//         point['latitude'] as double,
//         point['longitude'] as double,
//       )).toList() ?? [],
//       transportMode: json['transportMode'] ?? 'WALK',
//       duration: json['duration'] ?? 0,
//       distance: json['distance'] ?? 0.0,
//       color: color,
//     );
//   }
// }

class NavigationRoute {
  final String id;
  final List<LatLng> points;
  final String transportMode;
  final int duration;
  final double distance;
  final Color color;

  NavigationRoute({
    required this.id,
    required this.points,
    required this.transportMode,
    required this.duration,
    required this.distance,
    this.color = Colors.blue,
  });

  factory NavigationRoute.fromJson(Map<String, dynamic> json, Color color) {
    return NavigationRoute(
      id: json['segmentId'] ?? '',
      points: (json['path'] as List<dynamic>?)?.map((point) => LatLng(
        point['latitude'] as double,
        point['longitude'] as double,
      )).toList() ?? [],
      transportMode: json['transportMode'] ?? 'WALK',
      duration: json['duration'] ?? 0,
      distance: json['distance'] ?? 0.0,
      color: color,
    );
  }
}