
// lib/models/multiple_schedule_response.dart

class MultipleOptimizeResponse {
  final List<OptimizedOption> optimizedOptions;
  final ComparisonMetrics? comparison;

  MultipleOptimizeResponse({
    required this.optimizedOptions,
    this.comparison,
  });

  factory MultipleOptimizeResponse.fromJson(Map<String, dynamic> json) {
    return MultipleOptimizeResponse(
      optimizedOptions: (json['optimizedOptions'] as List?)
          ?.map((option) => OptimizedOption.fromJson(option))
          .toList() ?? [],
      comparison: json['comparison'] != null
          ? ComparisonMetrics.fromJson(json['comparison'])
          : null,
    );
  }
}

class OptimizedOption {
  final int optionId;
  final Map<String, dynamic> result; // OptimizeResponse와 동일한 구조
  final OptionScore score;
  final String recommendation;

  OptimizedOption({
    required this.optionId,
    required this.result,
    required this.score,
    required this.recommendation,
  });

  factory OptimizedOption.fromJson(Map<String, dynamic> json) {
    return OptimizedOption(
      optionId: json['optionId'] ?? 0,
      result: json['result'] ?? {},
      score: OptionScore.fromJson(json['score'] ?? {}),
      recommendation: json['recommendation'] ?? '',
    );
  }
}

class OptionScore {
  final double totalScore;
  final double timeEfficiency;
  final double distanceEfficiency;
  final double costEfficiency;
  final String grade;

  OptionScore({
    required this.totalScore,
    required this.timeEfficiency,
    required this.distanceEfficiency,
    required this.costEfficiency,
    required this.grade,
  });

  factory OptionScore.fromJson(Map<String, dynamic> json) {
    return OptionScore(
      totalScore: (json['totalScore'] ?? 0.0).toDouble(),
      timeEfficiency: (json['timeEfficiency'] ?? 0.0).toDouble(),
      distanceEfficiency: (json['distanceEfficiency'] ?? 0.0).toDouble(),
      costEfficiency: (json['costEfficiency'] ?? 0.0).toDouble(),
      grade: json['grade'] ?? 'F',
    );
  }
}

class ComparisonMetrics {
  final OptimizedOption? bestTimeOption;
  final OptimizedOption? bestDistanceOption;
  final OptimizedOption? bestCostOption;
  final OptimizedOption? recommendedOption;
  final ComparisonSummary? summary;

  ComparisonMetrics({
    this.bestTimeOption,
    this.bestDistanceOption,
    this.bestCostOption,
    this.recommendedOption,
    this.summary,
  });

  factory ComparisonMetrics.fromJson(Map<String, dynamic> json) {
    return ComparisonMetrics(
      bestTimeOption: json['bestTimeOption'] != null
          ? OptimizedOption.fromJson(json['bestTimeOption'])
          : null,
      bestDistanceOption: json['bestDistanceOption'] != null
          ? OptimizedOption.fromJson(json['bestDistanceOption'])
          : null,
      bestCostOption: json['bestCostOption'] != null
          ? OptimizedOption.fromJson(json['bestCostOption'])
          : null,
      recommendedOption: json['recommendedOption'] != null
          ? OptimizedOption.fromJson(json['recommendedOption'])
          : null,
      summary: json['summary'] != null
          ? ComparisonSummary.fromJson(json['summary'])
          : null,
    );
  }
}

class ComparisonSummary {
  final double timeVariancePercentage;
  final double distanceVariancePercentage;
  final int totalOptionsAnalyzed;
  final String overallRecommendation;

  ComparisonSummary({
    required this.timeVariancePercentage,
    required this.distanceVariancePercentage,
    required this.totalOptionsAnalyzed,
    required this.overallRecommendation,
  });

  factory ComparisonSummary.fromJson(Map<String, dynamic> json) {
    return ComparisonSummary(
      timeVariancePercentage: (json['timeVariancePercentage'] ?? 0.0).toDouble(),
      distanceVariancePercentage: (json['distanceVariancePercentage'] ?? 0.0).toDouble(),
      totalOptionsAnalyzed: json['totalOptionsAnalyzed'] ?? 0,
      overallRecommendation: json['overallRecommendation'] ?? '',
    );
  }
}