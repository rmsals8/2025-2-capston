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

      // 최적화된 일정 정보 추출
      List<dynamic> schedules = optimizedData['optimizedSchedules'] ?? [];
      List<dynamic> segments = optimizedData['routeSegments'] ?? [];
      Map<String, dynamic> metrics = optimizedData['metrics'] ?? {};

      // 일정 데이터 유효성 검사
      if (schedules.isEmpty) {
        throw Exception('저장할 일정 데이터가 없습니다.');
      }

      print('일정 저장 시작: $scheduleName (${expirationDays}일)');
      print('일정 항목 수: ${schedules.length}');

      // segments가 없는 경우 자동 생성
      if (segments.isEmpty && schedules.length > 1) {
        print('경로 정보가 없어 기본 경로를 생성합니다.');
        segments = _generateBasicSegments(schedules);
      }

      // 백엔드 API 기대형식에 맞게 변환
      final Map<String, dynamic> requestBody = {
        'scheduleName': scheduleName,
        'expirationDays': expirationDays,
        'optimizedSchedules': _convertOptimizedSchedules(schedules),
        'segments': _convertRouteSegments(segments),
        'metrics': {
          'totalDistance': _convertToDouble(metrics['totalDistance'] ?? 0.0),
          'totalDuration': _convertToInt(metrics['totalTime'] ?? 0),
          'totalCost': _convertToDouble(metrics['totalCost'] ?? 0.0),
        }
      };

      // 디버깅 로그
      print('최종 요청 데이터:');
      print(jsonEncode(requestBody));

      // API 요청
      final response = await http.post(
        Uri.parse('$baseUrl/schedules/saved'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('응답 상태 코드: ${response.statusCode}');
      print('응답 본문: ${utf8.decode(response.bodyBytes)}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('일정 저장 실패: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      print('일정 저장 오류: $e');
      rethrow;
    }
  }
  // Double 타입으로 안전하게 변환
  double _convertToDouble(dynamic value) {
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

// Int 타입으로 안전하게 변환
  int _convertToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }

// 기본 경로 세그먼트 생성 (일정 간의 이동 경로)
  List<Map<String, dynamic>> _generateBasicSegments(List<dynamic> schedules) {
    List<Map<String, dynamic>> segments = [];

    // 일정이 2개 이상일 때만 세그먼트 생성
    if (schedules.length < 2) return segments;

    for (int i = 0; i < schedules.length - 1; i++) {
      final current = schedules[i];
      final next = schedules[i + 1];

      segments.add({
        'fromLocation': current['name'] ?? '',
        'toLocation': next['name'] ?? '',
        'distance': 1.0,  // 기본값
        'duration': 30,   // 기본 30분
        'transportMode': 'WALK'  // 기본 이동 수단
      });
    }

    return segments;
  }
  // 최적화된 일정을 API 요청 형식으로 변환
  List<Map<String, dynamic>> _convertOptimizedSchedules(List<dynamic> schedules) {
    return schedules.map((schedule) {
      // 위치 정보 변환
      Map<String, dynamic> locationData = _extractLocationData(schedule);

      // duration 변환 (PT1H 같은 문자열을 정수로 변환)
      int duration = 60; // 기본값
      if (schedule['duration'] is int) {
        duration = schedule['duration'];
      } else if (schedule['duration'] is String) {
        String durStr = schedule['duration'].toString();
        if (durStr.startsWith('PT')) {
          if (durStr.contains('H')) {
            try {
              int hours = int.parse(durStr.split('PT')[1].split('H')[0]);
              duration = hours * 60;
            } catch (e) {
              print('시간 파싱 오류: $e');
            }
          } else if (durStr.contains('M')) {
            try {
              duration = int.parse(durStr.split('PT')[1].split('M')[0]);
            } catch (e) {
              print('분 파싱 오류: $e');
            }
          }
        } else {
          try {
            duration = int.parse(durStr);
          } catch (e) {
            print('일반 문자열 파싱 오류: $e');
          }
        }
      }

      return {
        'name': schedule['name'] ?? '',
        'location': {
          'latitude': locationData['latitude'],
          'longitude': locationData['longitude'],
          'name': locationData['locationName'] ?? schedule['name'] ?? '',
        },
        'startTime': _formatDateTime(schedule['startTime']),
        'endTime': _formatDateTime(schedule['endTime']),
        'type': schedule['type'] ?? 'FIXED',
        'priority': schedule['priority'] ?? 1,
        'duration': duration,  // 정수로 변환됨
      };
    }).toList();
  }

// 날짜 형식을 ISO 8601 형식으로 변환
  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) {
      return DateTime.now().toIso8601String();
    }

    if (dateTime is String) {
      try {
        final dt = DateTime.parse(dateTime);
        return dt.toIso8601String(); // ISO 형식: "2025-04-24T12:00:00"
      } catch (e) {
        return DateTime.now().toIso8601String();
      }
    }

    return DateTime.now().toIso8601String();
  }
// 경로 세그먼트 데이터 변환
  List<Map<String, dynamic>> _convertRouteSegments(List<dynamic> segments) {
    return segments.map((segment) {
      // 정수로 변환된 duration
      int duration = 0;
      if (segment['duration'] != null) {
        if (segment['duration'] is int) {
          duration = segment['duration'];
        } else {
          try {
            duration = int.parse(segment['duration'].toString());
          } catch (e) {
            duration = 30; // 기본값
          }
        }
      } else if (segment['estimatedTime'] != null) {
        if (segment['estimatedTime'] is int) {
          duration = segment['estimatedTime'];
        } else {
          try {
            duration = int.parse(segment['estimatedTime'].toString());
          } catch (e) {
            duration = 30; // 기본값
          }
        }
      } else {
        duration = 30; // 기본값
      }

      return {
        'fromLocation': segment['fromLocation'] ?? '',
        'toLocation': segment['toLocation'] ?? '',
        'distance': segment['distance'] is double ? segment['distance'] : double.parse(segment['distance'].toString()),
        'duration': duration,
        'transportMode': segment['transportMode'] ?? segment['recommendedRoute'] ?? 'WALK',
      };
    }).toList();
  }


  // 위치 데이터 추출 (여러 형태의 위치 데이터 처리)
  Map<String, dynamic> _extractLocationData(dynamic schedule) {
    double latitude = 0.0;
    double longitude = 0.0;
    String locationName = '';

    // 기본 좌표값 확인
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
          Map<String, dynamic> locationMap = jsonDecode(location);
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

  // ISO 8601 형식으로 날짜 변환 (백엔드가 예상하는 형식)
  String _ensureIsoFormat(dynamic dateTime) {
    if (dateTime == null) {
      return DateTime.now().toIso8601String();
    }

    if (dateTime is String) {
      // 이미 ISO 형식이면 그대로 반환
      if (dateTime.contains('T') && dateTime.contains('Z') ||
          dateTime.contains('T') && dateTime.contains('+')) {
        return dateTime;
      }

      // ISO 형식으로 파싱 시도
      try {
        final dt = DateTime.parse(dateTime);
        return dt.toIso8601String();
      } catch (e) {
        print('날짜 파싱 오류: $e, 기본값 사용');
        return DateTime.now().toIso8601String();
      }
    }

    // 다른 형식이면 현재 시간 반환
    return DateTime.now().toIso8601String();
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
        final Map<String, dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
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
        final Map<String, dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
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
}