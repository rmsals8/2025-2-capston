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
