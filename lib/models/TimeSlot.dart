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