// lib/models/route_option.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'route_segment.dart';

class RouteOption {
  final String id;
  final List<RouteSegment> segments;
  final int totalDuration;
  final double totalDistance;
  final double totalCost;
  final String transportMode;
  final double congestionLevel;
  final Color routeColor;
  final List<LatLng> points;
  final bool isSelected;

  RouteOption({
    required this.id,
    required this.segments,
    required this.totalDuration,
    required this.totalDistance,
    required this.totalCost,
    required this.transportMode,
    required this.congestionLevel,
    required this.routeColor,
    required this.points,
    this.isSelected = false,
  });

  RouteOption copyWith({
    String? id,
    List<RouteSegment>? segments,
    int? totalDuration,
    double? totalDistance,
    double? totalCost,
    String? transportMode,
    double? congestionLevel,
    Color? routeColor,
    List<LatLng>? points,
    bool? isSelected,
  }) {
    return RouteOption(
      id: id ?? this.id,
      segments: segments ?? this.segments,
      totalDuration: totalDuration ?? this.totalDuration,
      totalDistance: totalDistance ?? this.totalDistance,
      totalCost: totalCost ?? this.totalCost,
      transportMode: transportMode ?? this.transportMode,
      congestionLevel: congestionLevel ?? this.congestionLevel,
      routeColor: routeColor ?? this.routeColor,
      points: points ?? this.points,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  static List<LatLng> extractPoints(List<RouteSegment> segments) {
    List<LatLng> points = [];
    for (var segment in segments) {
      points.add(LatLng(segment.startLat, segment.startLon));
      points.add(LatLng(segment.endLat, segment.endLon));
    }
    return points;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'segments': segments.map((s) => s.toJson()).toList(),
      'totalDuration': totalDuration,
      'totalDistance': totalDistance,
      'totalCost': totalCost,
      'transportMode': transportMode,
      'congestionLevel': congestionLevel,
    };
  }

  static RouteOption fromJson(Map<String, dynamic> json, Color routeColor) {
    return RouteOption(
      id: json['id'],
      segments: (json['segments'] as List)
          .map((s) => RouteSegment.fromJson(s))
          .toList(),
      totalDuration: json['totalDuration'],
      totalDistance: json['totalDistance'],
      totalCost: json['totalCost'],
      transportMode: json['transportMode'],
      congestionLevel: json['congestionLevel'],
      routeColor: routeColor,
      points: extractPoints((json['segments'] as List)
          .map((s) => RouteSegment.fromJson(s))
          .toList()),
    );
  }
}