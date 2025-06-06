// lib/models/multiple_schedule_request.dart

class MultipleScheduleOptimizationRequest {
  final List<ScheduleOption> options;

  MultipleScheduleOptimizationRequest({required this.options});

  Map<String, dynamic> toJson() {
    return {
      'options': options.map((option) => option.toJson()).toList(),
    };
  }
}

class ScheduleOption {
  final int optionId;
  final List<FixedScheduleDTO> fixedSchedules;
  final List<FlexibleScheduleDTO> flexibleSchedules;

  ScheduleOption({
    required this.optionId,
    required this.fixedSchedules,
    required this.flexibleSchedules,
  });

  Map<String, dynamic> toJson() {
    return {
      'optionId': optionId,
      'fixedSchedules': fixedSchedules.map((schedule) => schedule.toJson()).toList(),
      'flexibleSchedules': flexibleSchedules.map((schedule) => schedule.toJson()).toList(),
    };
  }
}

class FixedScheduleDTO {
  final String id;
  final String name;
  final String type;
  final int duration;
  final int priority;
  final String location;
  final double latitude;
  final double longitude;
  final String startTime;
  final String endTime;

  FixedScheduleDTO({
    required this.id,
    required this.name,
    required this.type,
    required this.duration,
    required this.priority,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'duration': duration,
      'priority': priority,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}

class FlexibleScheduleDTO {
  final String id;
  final String name;
  final String type;
  final int duration;
  final int priority;

  FlexibleScheduleDTO({
    required this.id,
    required this.name,
    required this.type,
    required this.duration,
    required this.priority,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'duration': duration,
      'priority': priority,
    };
  }
}