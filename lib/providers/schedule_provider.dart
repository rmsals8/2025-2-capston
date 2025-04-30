import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../providers/auth_provider.dart';

class ScheduleProvider with ChangeNotifier {
  List<Schedule> _schedules = [];
  bool _isLoading = false;
  String? _error;
  final baseUrl = dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8081/api/v1';
  final AuthProvider authProvider;

  ScheduleProvider({required this.authProvider});

  List<Schedule> get schedules => _schedules;
  List<Schedule> get fixedSchedules => _schedules.where((s) => s.type == 'FIXED').toList();
  List<Schedule> get flexibleSchedules => _schedules.where((s) => s.type == 'FLEXIBLE').toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  // AuthProvider로부터 토큰 가져오기
  Future<String?> getToken() async {
    return authProvider.getToken();
  }

  // 거리 계산 함수 추가
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // 인코딩 디버깅 유틸리티 함수 추가
  void _printEncodingDebug(String label, String text) {
    print('$label (first 100 chars): ${text.substring(0, math.min(100, text.length))}');
    try {
      // 인코딩 테스트
      final utf8Encoded = utf8.encode(text);
      final utf8Decoded = utf8.decode(utf8Encoded);
      print('UTF-8 인코딩/디코딩 테스트: ${utf8Decoded == text ? "성공" : "실패"}');
    } catch (e) {
      print('인코딩 테스트 중 오류: $e');
    }
  }

  // 한글 인코딩 문제 해결을 위한 JSON 변환 함수 추가
  Map<String, dynamic> _ensureUtf8Encoding(Map<String, dynamic> data) {
    // 문자열 값이 있으면 UTF-8로 인코딩 후 다시 디코딩하여 확실히 UTF-8로 변환
    final jsonString = json.encode(data);
    _printEncodingDebug('변환 전 JSON', jsonString);
    
    // UTF-8 바이트로 변환 후 다시 디코딩하여 인코딩 정규화
    final utf8Bytes = utf8.encode(jsonString);
    final normalizedString = utf8.decode(utf8Bytes);
    
    _printEncodingDebug('변환 후 JSON', normalizedString);
    return json.decode(normalizedString);
  }

  // 인코딩 디버깅을 위한 로그 함수
  void _logSchedulesEncoding(List<Map<String, dynamic>> schedules) {
    if (schedules.isNotEmpty) {
      // 첫 번째 일정만 로그로 출력
      final firstSchedule = schedules.first;
      if (firstSchedule.containsKey('name')) {
        _printEncodingDebug('첫 번째 일정 이름', firstSchedule['name']);
      }
      if (firstSchedule.containsKey('location')) {
        _printEncodingDebug('첫 번째 일정 위치', firstSchedule['location']);
      }
    }
  }

  Future<Map<String, dynamic>> optimizeSchedules(List<Map<String, dynamic>> schedules) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 인코딩 디버깅
      print('원본 일정 인코딩 확인:');
      _logSchedulesEncoding(schedules);

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

      // JSON 직렬화 전 인코딩 확인
      print('요청 직렬화 전 인코딩 확인:');
      if (fixedSchedules.isNotEmpty) {
        _printEncodingDebug('고정 일정 첫 항목', json.encode(fixedSchedules.first));
      }
      if (flexibleSchedules.isNotEmpty) {
        _printEncodingDebug('유연 일정 첫 항목', json.encode(flexibleSchedules.first));
      }

      // 요청 본문 인코딩 확인
      final requestJson = json.encode(requestBody);
      print('Sending request to server: ${requestJson}');
      _printEncodingDebug('요청 본문', requestJson);

      // 인증 토큰 가져오기
      final token = await getToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다. 로그인이 필요합니다.');
      }

      final response = await http.post(
          Uri.parse('$baseUrl/schedules/optimize-1'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8', // 명시적으로 UTF-8 지정
            'Authorization': 'Bearer $token'
          },
          body: requestJson);

      if (response.statusCode == 200) {
        print('Response headers: ${response.headers}');
        print('Response encoding: ${response.request?.headers['accept-charset']}');
        
        // 인코딩 테스트 출력
        final String rawBody = response.body;
        print('Raw response (first 100 chars): ${rawBody.substring(0, math.min(100, rawBody.length))}');
        
        // 명시적으로 UTF-8로 디코딩
        final String utf8Body = utf8.decode(response.bodyBytes);
        print('UTF8 decoded (first 100 chars): ${utf8Body.substring(0, math.min(100, utf8Body.length))}');
        
        // 디코딩된 텍스트를 JSON으로 파싱
        final responseData = json.decode(utf8Body);
        
        // 응답 데이터 인코딩 확인
        print('응답 데이터 인코딩 확인:');
        if (responseData.containsKey('optimizedSchedules') && responseData['optimizedSchedules'].isNotEmpty) {
          final firstSchedule = responseData['optimizedSchedules'][0];
          if (firstSchedule.containsKey('name')) {
            _printEncodingDebug('응답 첫 번째 일정 이름', firstSchedule['name']);
          }
          if (firstSchedule.containsKey('locationString')) {
            _printEncodingDebug('응답 첫 번째 일정 위치', firstSchedule['locationString']);
          }
        }
        
        _isLoading = false;
        notifyListeners();
        return responseData;
      } else {
        throw Exception('서버 응답 오류: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}');
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

      // 인코딩 디버깅
      print('일정 데이터 인코딩 확인:');
      _logSchedulesEncoding(schedulesData);

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
        // 한글 데이터 인코딩 확인
        if (data.containsKey('name')) {
          final name = data['name'] as String;
          _printEncodingDebug('Schedule 변환 이름', name);
        }
        if (data.containsKey('location')) {
          final location = data['location'] as String;
          _printEncodingDebug('Schedule 변환 위치', location);
        }

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

      // 생성된 일정 확인
      if (newSchedules.isNotEmpty) {
        final firstSchedule = newSchedules.first;
        print('생성된 첫 번째 일정 이름: ${firstSchedule.name}');
        print('생성된 첫 번째 일정 위치: ${firstSchedule.location}');
      }

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

  // 날짜별로 일정을 그룹화
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

    // 각 그룹 내에서 시작 시간순으로 정렬
    for (final schedules in grouped.values) {
      schedules.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    return grouped;
  }
}