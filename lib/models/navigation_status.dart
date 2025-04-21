// lib/models/navigation_status.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';

class NavigationStatus {
  final LatLng currentLocation;
  final double bearing;
  final double distanceToNextPoint;
  final String nextInstruction;
  final double distanceToDestination;
  final int estimatedTimeToDestination;
  final bool isOffRoute;
  final double speed;

  NavigationStatus({
    required this.currentLocation,
    required this.bearing,
    required this.distanceToNextPoint,
    required this.nextInstruction,
    required this.distanceToDestination,
    required this.estimatedTimeToDestination,
    required this.isOffRoute,
    required this.speed,
  });

  factory NavigationStatus.fromJson(Map<String, dynamic> json) {
    return NavigationStatus(
      currentLocation: LatLng(
        json['currentLocation']['latitude'],
        json['currentLocation']['longitude'],
      ),
      bearing: json['bearing'].toDouble(),
      distanceToNextPoint: json['distanceToNextPoint'].toDouble(),
      nextInstruction: json['nextInstruction'],
      distanceToDestination: json['distanceToDestination'].toDouble(),
      estimatedTimeToDestination: json['estimatedTimeToDestination'],
      isOffRoute: json['isOffRoute'],
      speed: json['speed'].toDouble(),
    );
  }
}