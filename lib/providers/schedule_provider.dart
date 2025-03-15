import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' ;
class ScheduleProvider with ChangeNotifier {
  List<Schedule> _schedules = [];
  bool _isLoading = false;
  String? _error;
  // static const String baseUrl = 'http://10.0.2.2:8080/api/v1';  // baseUrl 추가
  final baseUrl = dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8080/api/v1';
  List<Schedule> get schedules => _schedules;
  List<Schedule> get fixedSchedules => _schedules.where((s) => s.type == 'FIXED').toList();
  List<Schedule> get flexibleSchedules => _schedules.where((s) => s.type == 'FLEXIBLE').toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 거리 계산 함수 추가
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

// lib/providers/schedule_provider.dart
  Future<Map<String, dynamic>> optimizeSchedules(List<Map<String, dynamic>> schedules) async {
    try {
      _isLoading = true;
      notifyListeners();

      print('Submitting schedules: $schedules');

      // 좌표값 수정
      schedules = schedules.map((schedule) {
        Map<String, dynamic> copy = Map<String, dynamic>.from(schedule);

        // 너무 큰 좌표값 수정
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
          .toList();

      final flexibleSchedules = schedules
          .where((s) => s['type'] == 'FLEXIBLE')
          .toList();

      final requestBody = {
        'fixedSchedules': fixedSchedules,
        'flexibleSchedules': flexibleSchedules
      };

      print('Sending request to server: ${json.encode(requestBody)}');

      final response = await http.post(
          Uri.parse('$baseUrl/schedules/optimize-1'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _isLoading = false;
        notifyListeners();
        return responseData;
      } else {
        throw Exception('서버 응답 오류: ${response.statusCode}\n${response.body}');
      }
    } catch (e, stackTrace) {
      print('Error during optimization: $e');
      print('Stack trace: $stackTrace');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      throw Exception('일정 최적화 중 오류가 발생했습니다: $e');
    }
  }
// 가장 적합한 장소 찾기
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

// 장소 점수 계산
  double calculatePlaceScore(
      Map<String, dynamic> place,
      Map<String, dynamic> prevSchedule,
      Map<String, dynamic> nextSchedule,
      ) {
    // 1. 이전 일정과의 거리
    final distFromPrev = calculateDistance(
      prevSchedule['latitude'],
      prevSchedule['longitude'],
      place['latitude'],
      place['longitude'],
    );

    // 2. 다음 일정과의 거리
    final distToNext = calculateDistance(
      place['latitude'],
      place['longitude'],
      nextSchedule['latitude'],
      nextSchedule['longitude'],
    );

    // 거리가 짧을수록 높은 점수
    return 1000 / (distFromPrev + distToNext);
  }
  void createMultipleSchedules(List<Map<String, dynamic>> schedulesData) {
    try {
      _isLoading = true;
      notifyListeners();

      // 시작 시간 기준으로 정렬
      schedulesData.sort((a, b) {
        DateTime aTime = DateTime.parse(a['startTime'] as String);
        DateTime bTime = DateTime.parse(b['startTime'] as String);
        return aTime.compareTo(bTime);
      });

      // 시간 중복 체크 및 조정
      for (int i = 1; i < schedulesData.length; i++) {
        DateTime prevEnd = DateTime.parse(schedulesData[i - 1]['endTime']);
        DateTime currStart = DateTime.parse(schedulesData[i]['startTime']);
        int duration = schedulesData[i]['duration'] as int;

        if (currStart.isBefore(prevEnd) || currStart.isAtSameMomentAs(prevEnd)) {
          // 이전 일정 종료 시간 이후로 시작 시간 조정 (5분 버퍼 추가)
          DateTime newStart = prevEnd.add(const Duration(minutes: 5));
          schedulesData[i]['startTime'] = newStart.toIso8601String();
          schedulesData[i]['endTime'] = newStart
              .add(Duration(minutes: duration))
              .toIso8601String();
        }
      }

      // 좌표값 형식 변환 및 일정 생성
      List<Schedule> newSchedules = schedulesData.map((data) {
        // 좌표값 변환 (정수형인 경우에만)
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

      // 기존 일정에 추가
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
}