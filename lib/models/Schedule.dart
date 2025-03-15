class Schedule {
  final String id;
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final String type;  // 'FIXED' or 'FLEXIBLE'
  final int priority;
  final double latitude;
  final double longitude;
  final int duration;  // Added duration parameter

  Schedule({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.type,
    required this.priority,
    required this.latitude,
    required this.longitude,
    required this.duration,  // Added to constructor
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'],
      name: json['name'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      location: json['location'],
      type: json['type'],
      priority: json['priority'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      duration: json['duration'] ?? 60,  // Default to 60 minutes if not provided
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'type': type,
      'priority': priority,
      'latitude': latitude,
      'longitude': longitude,
      'duration': duration,
    };
  }
}