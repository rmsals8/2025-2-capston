// lib/models/route_model.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import '../models/route.dart' as app_route;  // 이렇게 import하고
class RouteModel {
  final String id;
  final List<LatLng> points;
  final double distance;
  final int duration;
  final String transportMode;
  final Color routeColor;
  final double estimatedCost;
  final String summary;
  final List<String> instructions;

  RouteModel({
    required this.id,
    required this.points,
    required this.distance,
    required this.duration,
    required this.transportMode,
    required this.routeColor,
    required this.estimatedCost,
    required this.summary,
    required this.instructions,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'],
      points: _parsePoints(json['points']),
      distance: json['distance'].toDouble(),
      duration: json['duration'],
      transportMode: json['transportMode'],
      routeColor: _getRouteColor(json['transportMode']),
      estimatedCost: json['estimatedCost'].toDouble(),
      summary: json['summary'],
      instructions: List<String>.from(json['instructions']),
    );
  }

  static List<LatLng> _parsePoints(List<dynamic> pointsList) {
    return pointsList.map((point) => LatLng(
      point['latitude'].toDouble(),
      point['longitude'].toDouble(),
    )).toList();
  }

  static Color _getRouteColor(String transportMode) {
    switch (transportMode.toLowerCase()) {
      case 'walk':
        return Colors.green;
      case 'car':
        return Colors.blue;
      case 'taxi':
        return Colors.orange;
      case 'bus':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Route를 RouteModel로 변환하는 새로운 생성자 수정
  factory RouteModel.fromRoute(app_route.Route route) {  // app_route.Route로 타입 지정
    return RouteModel(
      id: route.id,
      points: route.segments.expand((segment) => [
        LatLng(segment.startLat, segment.startLon),
        LatLng(segment.endLat, segment.endLon),
      ]).toList(),
      distance: route.totalDistance,
      duration: route.totalDuration,
      transportMode: route.transportMode,
      routeColor: route.routeColor,
      estimatedCost: route.totalCost,
      summary: route.summary,
      instructions: route.segments.map((segment) => segment.instruction).toList(),
    );
  }
}