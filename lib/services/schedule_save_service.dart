import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ScheduleSaveService {
  String get baseUrl {
    if (kIsWeb) {
      // 웹 환경에서는 localhost 사용
      return dotenv.env['API_V1_URL'] ?? 'http://localhost:8081/api/v1';
    } else {
      // 모바일 환경에서는 10.0.2.2 (에뮬레이터용) 또는 설정된 URL 사용
      return dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8081/api/v1';
    }
  }

  // 최적화된 일정 저장
  Future<Map<String, dynamic>> saveSchedule({
    required String scheduleName,
    required int expirationDays,
    required Map<String, dynamic> optimizedData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        throw Exception('인증 토큰이 없습니다. 로그인이 필요합니다.');
      }

      // 요청 바디 구성
      final Map<String, dynamic> requestBody = {
        'scheduleName': scheduleName,
        'expirationDays': expirationDays,
        'optimizedSchedules': _convertOptimizedSchedules(optimizedData['optimizedSchedules']),
        'segments': _convertRouteSegments(optimizedData['routeSegments'] ?? []),
        'metrics': {
          'totalDistance': optimizedData['metrics']?['totalDistance'] ?? 0.0,
          'totalDuration': optimizedData['metrics']?['totalTime'] ?? 0,
          'totalCost': optimizedData['metrics']?['totalCost'] ?? 0.0,
        }
      };

      // API 요청
      final response = await http.post(
        Uri.parse('$baseUrl/schedules/saved'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('일정 저장 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('일정 저장 오류: $e');
      rethrow;
    }
  }

  // 저장된 일정 목록 조회
  Future<List<Map<String, dynamic>>> getSavedSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        throw Exception('인증 토큰이 없습니다. 로그인이 필요합니다.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/schedules/saved/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        if (responseData['data'] != null && responseData['data'] is List) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        }
        return [];
      } else {
        throw Exception('저장된 일정 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('저장된 일정 조회 오류: $e');
      return [];
    }
  }

  // 저장된 일정 상세 조회
  Future<Map<String, dynamic>> getSavedScheduleDetail(int scheduleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        throw Exception('인증 토큰이 없습니다. 로그인이 필요합니다.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/schedules/saved/$scheduleId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        if (responseData['data'] != null) {
          return responseData['data'];
        }
        throw Exception('일정 데이터가 없습니다.');
      } else {
        throw Exception('일정 상세 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('일정 상세 조회 오류: $e');
      rethrow;
    }
  }

  // 저장된 일정 삭제
  Future<bool> deleteSavedSchedule(int scheduleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        throw Exception('인증 토큰이 없습니다. 로그인이 필요합니다.');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/schedules/saved/$scheduleId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('일정 삭제 오류: $e');
      return false;
    }
  }

  // 최적화된 일정을 API 요청 형식으로 변환
  List<Map<String, dynamic>> _convertOptimizedSchedules(List<dynamic>? schedules) {
    if (schedules == null) return [];

    return schedules.map((schedule) {
      // 위치 정보 추출 (다양한 형태 처리)
      Map<String, dynamic> locationData = _extractLocationData(schedule);

      return {
        'name': schedule['name'] ?? '',
        'location': {
          'latitude': locationData['latitude'],
          'longitude': locationData['longitude'],
          'name': locationData['locationName'] ?? schedule['name'] ?? '',
        },
        'startTime': schedule['startTime'] ?? DateTime.now().toIso8601String(),
        'endTime': schedule['endTime'] ?? DateTime.now().toIso8601String(),
        'type': schedule['type'] ?? 'FIXED',
        'priority': schedule['priority'] ?? 1,
        'duration': schedule['duration'] ?? 60,
      };
    }).toList();
  }

  // 경로 세그먼트 데이터 변환
  List<Map<String, dynamic>> _convertRouteSegments(List<dynamic> segments) {
    return segments.map((segment) {
      return {
        'fromLocation': segment['fromLocation'] ?? '',
        'toLocation': segment['toLocation'] ?? '',
        'distance': segment['distance'] ?? 0.0,
        'duration': segment['estimatedTime'] ?? 0,
        'transportMode': segment['recommendedRoute'] ?? 'WALK',
      };
    }).toList();
  }

  // 위치 데이터 추출 (여러 형태의 위치 데이터 처리)
  Map<String, dynamic> _extractLocationData(dynamic schedule) {
    double latitude = 0.0;
    double longitude = 0.0;
    String locationName = '';

    // 기본 좌표값
    if (schedule['latitude'] != null && schedule['longitude'] != null) {
      latitude = _parseDouble(schedule['latitude']);
      longitude = _parseDouble(schedule['longitude']);
    }

    // location 객체가 있는 경우
    if (schedule['location'] != null) {
      dynamic location = schedule['location'];
      
      // Map 형태인 경우
      if (location is Map) {
        latitude = location['latitude'] != null ? _parseDouble(location['latitude']) : latitude;
        longitude = location['longitude'] != null ? _parseDouble(location['longitude']) : longitude;
        locationName = location['name'] ?? '';
      } 
      // 문자열이지만 JSON 형태인 경우
      else if (location is String && location.startsWith('{')) {
        try {
          Map<String, dynamic> locationMap = json.decode(location);
          latitude = locationMap['latitude'] != null ? _parseDouble(locationMap['latitude']) : latitude;
          longitude = locationMap['longitude'] != null ? _parseDouble(locationMap['longitude']) : longitude;
          locationName = locationMap['name'] ?? '';
        } catch (e) {
          print('위치 정보 파싱 오류: $e');
          locationName = location;
        }
      }
      // 단순 문자열인 경우
      else if (location is String) {
        locationName = location;
      }
    }

    // locationString이 있는 경우
    if (schedule['locationString'] != null && locationName.isEmpty) {
      locationName = schedule['locationString'];
    }

    return {
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
    };
  }

  // 다양한 형태의 숫자 데이터를 double로 변환
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }
}