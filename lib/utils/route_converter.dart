// lib/utils/route_converter.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/route.dart' as app_route;
import '../models/route_option.dart';

class RouteConverter {
  static RouteOption fromRoute(app_route.Route route) {
    return RouteOption(
      id: route.id,
      segments: route.segments,
      totalDuration: route.totalDuration,
      totalDistance: route.totalDistance,
      totalCost: route.totalCost,
      transportMode: route.transportMode,
      congestionLevel: route.congestionLevel,
      routeColor: route.routeColor,
      points: route.segments.expand((segment) => [
        LatLng(segment.startLat, segment.startLon),
        LatLng(segment.endLat, segment.endLon),
      ]).toList(),
    );
  }

  static app_route.Route toRoute(RouteOption routeOption) {
    return app_route.Route(
      id: routeOption.id,
      segments: routeOption.segments,
      totalDuration: routeOption.totalDuration,
      totalDistance: routeOption.totalDistance,
      totalCost: routeOption.totalCost,
      transportMode: routeOption.transportMode,
      congestionLevel: routeOption.congestionLevel,
      summary: '',  // 필요한 경우 적절한 요약 정보 추가
    );
  }
}