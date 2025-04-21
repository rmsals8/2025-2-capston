// models/route_analysis.dart
import '../models/route.dart';

class RouteAnalysis {
  final RouteMetrics routeMetrics;
  final List<TimeSlot> timeSlots;
  final Map<String, double> categoryDistribution;
  final OptimizationInfo optimization;

  RouteAnalysis({
    required this.routeMetrics,
    required this.timeSlots,
    required this.categoryDistribution,
    required this.optimization,
  });

  factory RouteAnalysis.fromJson(Map<String, dynamic> json) {
    return RouteAnalysis(
      routeMetrics: RouteMetrics.fromJson(json['routeMetrics']),
      timeSlots: (json['timeSlots'] as List)
          .map((slot) => TimeSlot.fromJson(slot))
          .toList(),
      categoryDistribution: Map<String, double>.from(json['categoryDistribution']),
      optimization: OptimizationInfo.fromJson(json['optimization']),
    );
  }

}

class RouteMetrics {
  final double totalDistance;
  final int totalDuration;
  final String difficulty;
  final double averageSpeed;
  final int totalStops;
  final Map<String, dynamic> modeSplit;

  RouteMetrics({
    required this.totalDistance,
    required this.totalDuration,
    required this.difficulty,
    required this.averageSpeed,
    required this.totalStops,
    required this.modeSplit,
  });

  factory RouteMetrics.fromJson(Map<String, dynamic> json) {
    return RouteMetrics(
      totalDistance: json['totalDistance']?.toDouble() ?? 0.0,
      totalDuration: json['totalDuration'] ?? 0,
      difficulty: json['difficulty'] ?? 'EASY',
      averageSpeed: json['averageSpeed']?.toDouble() ?? 0.0,
      totalStops: json['totalStops'] ?? 0,
      modeSplit: json['modeSplit'] ?? {},
    );
  }
}

class TimeSlot {
  final String startTime;
  final String endTime;
  final double crowdedness;
  final String trafficCondition;
  final List<String> considerations;
  final bool rushHour;
  final bool optimalTime;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.crowdedness,
    required this.trafficCondition,
    required this.considerations,
    required this.rushHour,
    required this.optimalTime,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      crowdedness: json['crowdedness']?.toDouble() ?? 0.0,
      trafficCondition: json['trafficCondition'] ?? '',
      considerations: (json['considerations'] as List?)?.cast<String>() ?? [],
      rushHour: json['rushHour'] ?? false,
      optimalTime: json['optimalTime'] ?? false,
    );
  }
}

class OptimizationInfo {
  final int iterationCount;
  final double originalDuration;
  final double optimizedDuration;
  final double improvementPercentage;
  final List<String> appliedStrategies;
  final Map<String, double>? scores;

  OptimizationInfo({
    required this.iterationCount,
    required this.originalDuration,
    required this.optimizedDuration,
    required this.improvementPercentage,
    required this.appliedStrategies,
    this.scores,
  });

  factory OptimizationInfo.fromJson(Map<String, dynamic> json) {
    return OptimizationInfo(
      iterationCount: json['iterationCount'] ?? 0,
      originalDuration: json['originalDuration']?.toDouble() ?? 0.0,
      optimizedDuration: json['optimizedDuration']?.toDouble() ?? 0.0,
      improvementPercentage: json['improvementPercentage']?.toDouble() ?? 0.0,
      appliedStrategies: (json['appliedStrategies'] as List?)?.cast<String>() ?? [],
      scores: json['scores']?.cast<String, double>(),
    );
  }
}