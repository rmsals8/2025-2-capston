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