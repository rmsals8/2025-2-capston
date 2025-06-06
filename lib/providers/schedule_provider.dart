import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/schedule.dart';
import '../models/multiple_schedule_request.dart';
import '../models/multiple_schedule_response.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../providers/auth_provider.dart';

class ScheduleProvider with ChangeNotifier {
  List<Schedule> _schedules = [];
  bool _isLoading = false;
  String? _error;
  final baseUrl = 'https://port-0-capston-m8dskoec57d8f7b3.sel4.cloudtype.app/api/v1';
  // final baseUrl = 'http://192.168.11.1:8086/api/v1';
  final AuthProvider authProvider;

  ScheduleProvider({required this.authProvider});

  List<Schedule> get schedules => _schedules;
  List<Schedule> get fixedSchedules => _schedules.where((s) => s.type == 'FIXED').toList();
  List<Schedule> get flexibleSchedules => _schedules.where((s) => s.type == 'FLEXIBLE').toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<String?> getToken() async {
    return authProvider.getToken();
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // 기존 optimizeSchedules 메소드를 다중 최적화로 완전히 교체
  Future<MultipleOptimizeResponse> optimizeSchedules(List<Map<String, dynamic>> schedules) async {
    try {
      _isLoading = true;
      notifyListeners();

      print('Submitting schedules for multiple optimization: $schedules');

      // 좌표값 수정
      schedules = schedules.map((schedule) {
        Map<String, dynamic> copy = Map<String, dynamic>.from(schedule);

        if (copy['latitude'] != null) {
          double lat = copy['latitude'];
          double lng = copy['longitude'];

          if (lat > 180) {
            copy['latitude'] = lat / 10000000;
          }
          if (lng > 180) {
            copy['longitude'] = lng / 10000000;
          }
        }
        return copy;
      }).toList();

      // 단일 옵션을 다중 옵션 형태로 변환
      List<ScheduleOption> options = [];

      final fixedSchedules = schedules
          .where((s) => s['type'] == 'FIXED')
          .map((s) => FixedScheduleDTO(
        id: s['id'],
        name: s['name'],
        type: s['type'],
        duration: s['duration'],
        priority: s['priority'],
        location: s['location'],
        latitude: s['latitude'],
        longitude: s['longitude'],
        startTime: s['startTime'],
        endTime: s['endTime'],
      ))
          .toList();

      final flexibleSchedules = schedules
          .where((s) => s['type'] == 'FLEXIBLE')
          .map((s) => FlexibleScheduleDTO(
        id: s['id'],
        name: s['name'],
        type: s['type'],
        duration: s['duration'],
        priority: s['priority'],
      ))
          .toList();

      // 단일 옵션만 생성 (나중에 UI에서 여러 옵션을 만들 수 있음)
      options.add(ScheduleOption(
        optionId: 1,
        fixedSchedules: fixedSchedules,
        flexibleSchedules: flexibleSchedules,
      ));

      final request = MultipleScheduleOptimizationRequest(options: options);

      print('Sending multiple optimization request: ${json.encode(request.toJson())}');

      final token = await getToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다. 로그인이 필요합니다.');
      }

      final response = await http.post(
          Uri.parse('$baseUrl/schedules/optimize-multiple'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $token'
          },
          body: utf8.encode(json.encode(request.toJson())));

      if (response.statusCode == 200) {
        final jsonString = utf8.decode(response.bodyBytes);
        final responseData = json.decode(jsonString);
        _isLoading = false;
        notifyListeners();
        return MultipleOptimizeResponse.fromJson(responseData);
      } else {
        throw Exception('서버 응답 오류: ${response.statusCode}\n${response.body}');
      }
    } catch (e, stackTrace) {
      print('Error during multiple optimization: $e');
      print('Stack trace: $stackTrace');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      throw Exception('일정 최적화 중 오류가 발생했습니다: $e');
    }
  }

  // 진짜 다중 옵션 최적화 메소드 (여러 옵션을 받을 때)
  Future<MultipleOptimizeResponse> optimizeMultipleScheduleOptions(List<List<Map<String, dynamic>>> scheduleOptions) async {
    try {
      _isLoading = true;
      notifyListeners();

      List<ScheduleOption> options = [];

      for (int i = 0; i < scheduleOptions.length; i++) {
        List<Map<String, dynamic>> schedules = scheduleOptions[i];

        // 좌표값 수정
        schedules = schedules.map((schedule) {
          Map<String, dynamic> copy = Map<String, dynamic>.from(schedule);

          if (copy['latitude'] != null) {
            double lat = copy['latitude'];
            double lng = copy['longitude'];

            if (lat > 180) {
              copy['latitude'] = lat / 10000000;
            }
            if (lng > 180) {
              copy['longitude'] = lng / 10000000;
            }
          }
          return copy;
        }).toList();

        final fixedSchedules = schedules
            .where((s) => s['type'] == 'FIXED')
            .map((s) => FixedScheduleDTO(
          id: s['id'],
          name: s['name'],
          type: s['type'],
          duration: s['duration'],
          priority: s['priority'],
          location: s['location'],
          latitude: s['latitude'],
          longitude: s['longitude'],
          startTime: s['startTime'],
          endTime: s['endTime'],
        ))
            .toList();

        final flexibleSchedules = schedules
            .where((s) => s['type'] == 'FLEXIBLE')
            .map((s) => FlexibleScheduleDTO(
          id: s['id'],
          name: s['name'],
          type: s['type'],
          duration: s['duration'],
          priority: s['priority'],
        ))
            .toList();

        options.add(ScheduleOption(
          optionId: i + 1,
          fixedSchedules: fixedSchedules,
          flexibleSchedules: flexibleSchedules,
        ));
      }

      final request = MultipleScheduleOptimizationRequest(options: options);

      print('Sending multiple optimization request: ${request.toJson()}');

      final token = await getToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다. 로그인이 필요합니다.');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/schedules/optimize-multiple'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token'
        },
        body: utf8.encode(json.encode(request.toJson())),
      );

      if (response.statusCode == 200) {
        final jsonString = utf8.decode(response.bodyBytes);
        final responseData = json.decode(jsonString);
        _isLoading = false;
        notifyListeners();
        return MultipleOptimizeResponse.fromJson(responseData);
      } else {
        throw Exception('서버 응답 오류: ${response.statusCode}\n${response.body}');
      }
    } catch (e, stackTrace) {
      print('Error during multiple optimization: $e');
      print('Stack trace: $stackTrace');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      throw Exception('다중 일정 최적화 중 오류가 발생했습니다: $e');
    }
  }

  // 나머지 기존 메소드들은 그대로 유지
  Map<String, dynamic> findBestPlace(
      List<Map<String, dynamic>> places,
      Map<String, dynamic> prevSchedule,
      Map<String, dynamic> nextSchedule,
      ) {
    return places.reduce((best, current) {
      final bestScore = calculatePlaceScore(best, prevSchedule, nextSchedule);
      final currentScore = calculatePlaceScore(current, prevSchedule, nextSchedule);
      return bestScore > currentScore ? best : current;
    });
  }

  double calculatePlaceScore(
      Map<String, dynamic> place,
      Map<String, dynamic> prevSchedule,
      Map<String, dynamic> nextSchedule,
      ) {
    final distFromPrev = calculateDistance(
      prevSchedule['latitude'],
      prevSchedule['longitude'],
      place['latitude'],
      place['longitude'],
    );

    final distToNext = calculateDistance(
      place['latitude'],
      place['longitude'],
      nextSchedule['latitude'],
      nextSchedule['longitude'],
    );

    return 1000 / (distFromPrev + distToNext);
  }

  void createMultipleSchedules(List<Map<String, dynamic>> schedulesData) {
    try {
      _isLoading = true;
      notifyListeners();

      schedulesData.sort((a, b) {
        DateTime aTime = DateTime.parse(a['startTime'] as String);
        DateTime bTime = DateTime.parse(b['startTime'] as String);
        return aTime.compareTo(bTime);
      });

      for (int i = 1; i < schedulesData.length; i++) {
        DateTime prevEnd = DateTime.parse(schedulesData[i - 1]['endTime']);
        DateTime currStart = DateTime.parse(schedulesData[i]['startTime']);
        int duration = schedulesData[i]['duration'] as int;

        if (currStart.isBefore(prevEnd) || currStart.isAtSameMomentAs(prevEnd)) {
          DateTime newStart = prevEnd.add(const Duration(minutes: 5));
          schedulesData[i]['startTime'] = newStart.toIso8601String();
          schedulesData[i]['endTime'] = newStart
              .add(Duration(minutes: duration))
              .toIso8601String();
        }
      }

      List<Schedule> newSchedules = schedulesData.map((data) {
        double latitude = data['latitude'] is int
            ? (data['latitude'] as int) / 10000000.0
            : (data['latitude'] as num).toDouble();
        double longitude = data['longitude'] is int
            ? (data['longitude'] as int) / 10000000.0
            : (data['longitude'] as num).toDouble();

        return Schedule(
          id: data['id'] as String,
          name: data['name'] as String,
          startTime: DateTime.parse(data['startTime']),
          endTime: DateTime.parse(data['endTime']),
          location: data['location'] as String,
          type: data['type'] as String,
          priority: data['priority'] as int,
          latitude: latitude,
          longitude: longitude,
          duration: data['duration'] as int,
        );
      }).toList();

      _schedules.addAll(newSchedules);

      _error = null;
      _isLoading = false;
      notifyListeners();

    } catch (e) {
      _error = '일정 생성 중 오류가 발생했습니다: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      throw Exception('Failed to create schedules: ${e.toString()}');
    }
  }

  void deleteSchedule(String id) {
    _schedules.removeWhere((schedule) => schedule.id == id);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void loadSchedules() {
    notifyListeners();
  }

  void addSchedule(Schedule schedule) {
    _schedules.add(schedule);
    notifyListeners();
  }

  void removeSchedule(Schedule schedule) {
    _schedules.removeWhere((item) => item.id == schedule.id);
    notifyListeners();
  }

  void updateSchedule(Schedule updatedSchedule) {
    final index = _schedules.indexWhere((schedule) => schedule.id == updatedSchedule.id);
    if (index != -1) {
      _schedules[index] = updatedSchedule;
      notifyListeners();
    }
  }

  Map<DateTime, List<Schedule>> groupSchedulesByDay() {
    final Map<DateTime, List<Schedule>> grouped = {};

    for (final schedule in _schedules) {
      final date = DateTime(
        schedule.startTime.year,
        schedule.startTime.month,
        schedule.startTime.day,
      );

      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }

      grouped[date]!.add(schedule);
    }

    for (final schedules in grouped.values) {
      schedules.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    return grouped;
  }
}