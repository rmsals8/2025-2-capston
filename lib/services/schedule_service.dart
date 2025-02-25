import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/schedule.dart';

class ScheduleService {
  static const String _baseUrl = 'http://10.0.2.2:8080/api/v1/schedules';

  Future<List<Schedule>> getSchedules() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/list'));

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => Schedule.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load schedules');
      }
    } catch (e) {
      throw Exception('Error fetching schedules: $e');
    }
  }

  Future<Schedule> createSchedule(Map<String, dynamic> scheduleData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/create'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(scheduleData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Schedule.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create schedule');
      }
    } catch (e) {
      throw Exception('Error creating schedule: $e');
    }
  }

  Future<List<Schedule>> createMultipleSchedules(List<Map<String, dynamic>> schedulesData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/create/multiple'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(schedulesData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => Schedule.fromJson(item)).toList();
      } else {
        throw Exception('Failed to create multiple schedules');
      }
    } catch (e) {
      throw Exception('Error creating multiple schedules: $e');
    }
  }

  Future<List<Schedule>> optimizeSchedule({
    required List<Schedule> fixedSchedules,
    required List<Schedule> flexibleSchedules
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/optimize'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'fixedSchedules': fixedSchedules.map((s) => s.toJson()).toList(),
          'flexibleSchedules': flexibleSchedules.map((s) => s.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => Schedule.fromJson(item)).toList();
      } else {
        throw Exception('Failed to optimize schedules');
      }
    } catch (e) {
      throw Exception('Error optimizing schedules: $e');
    }
  }

  Future<void> deleteSchedule(String scheduleId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/delete/$scheduleId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete schedule');
      }
    } catch (e) {
      throw Exception('Error deleting schedule: $e');
    }
  }
}