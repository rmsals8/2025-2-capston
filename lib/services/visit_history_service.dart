// lib/services/visit_history_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/visit_history.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as Math;
import 'package:flutter_dotenv/flutter_dotenv.dart' ;
class VisitHistoryService {
  static String? _cachedToken;  // 이 줄 추가
  static DateTime? _tokenTime;  // 이 줄 추가
  static const String _storageKey = 'visit_history';
  final Uuid _uuid = const Uuid();
  // final String baseUrl = 'http://10.0.2.2:8080/api/v1/visit-histories';
  static final String baseUrl = "${dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8080/api/v1'}/visit-histories";
  Future<String?> _getToken() async {
    // 5분간 토큰 캐시
    if (_cachedToken != null && _tokenTime != null &&
        DateTime.now().difference(_tokenTime!).inMinutes < 5) {
      return _cachedToken;
    }

    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('access_token');
    _tokenTime = DateTime.now();
    return _cachedToken;
  }
  // 페이징 처리된 방문 기록 조회
  Future<Map<String, dynamic>> getVisitHistoriesPaged({
    String? category,
    int page = 0,
    int size = 10,
  }) async {
    try {
      final token = await _getToken();

      print('페이징 방문 기록 API 요청에 사용되는 토큰: $token');

      if (token == null) {
        throw Exception('Authentication required');
      }

      String authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

      String url = '$baseUrl/paged?page=$page&size=$size';
      if (category != null && category.isNotEmpty && category != '전체') {
        url += '&category=$category';
      }

      print('페이징 방문 기록 API 요청 URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': authHeader
        },
      );

      print('페이징 방문 기록 API 응답 상태 코드: ${response.statusCode}');
      print('페이징 방문 기록 API 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 200 && jsonResponse['data'] != null) {
          final Map<String, dynamic> pageInfo = jsonResponse['data'];
          final List<dynamic> historyList = pageInfo['content'] ?? [];

          // 방문 기록 객체로 변환
          final List<VisitHistory> histories = historyList
              .map((item) => VisitHistory.fromJson(item))
              .toList();

          // 페이징 정보와 데이터를 함께 반환
          return {
            'histories': histories,
            'totalPages': pageInfo['totalPages'] ?? 0,
            'currentPage': pageInfo['currentPage'] ?? 0,
            'totalElements': pageInfo['totalElements'] ?? 0,
            'isFirst': pageInfo['first'] ?? true,
            'isLast': pageInfo['last'] ?? true,
            'isEmpty': pageInfo['empty'] ?? true,
          };
        } else {
          print('응답 데이터 형식이 올바르지 않습니다: ${jsonResponse['message']}');
          return {
            'histories': <VisitHistory>[],
            'totalPages': 0,
            'currentPage': 0,
            'totalElements': 0,
            'isFirst': true,
            'isLast': true,
            'isEmpty': true,
          };
        }
      } else {
        throw Exception('방문 기록을 가져오는데 실패했습니다: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('페이징 방문 기록 가져오기 오류: $e');
      throw Exception('페이징 방문 기록 조회 중 오류 발생: $e');
    }
  }
  // 방문 기록 추가 함수에도 비슷한 디버깅 추가
  Future<void> addVisitHistory(String placeName, String placeId, String category,
      double latitude, double longitude, String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      // 토큰 디버깅
      print('Access token found: ${token != null}');
      if (token != null) {
        print('Token length: ${token.length}');
        print('Token preview: ${token.substring(0, Math.min(20, token.length))}...');
      }

      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 요청 데이터 로깅
      final data = {
        'placeName': placeName,
        'placeId': placeId,
        'category': category,
        'latitude': latitude,
        'longitude': longitude,
        'address': address
      };

      print('방문 기록 추가 요청 데이터: $data');

      // Bearer 접두사 확인하여 중복 방지
      final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

      print('방문 기록 추가 요청 헤더의 Authorization: $authHeader');

      final response = await http.post(
        Uri.parse('${baseUrl}/add'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader,
        },
        body: json.encode(data),
      );

      // 응답 코드와 본문 로깅
      print('방문 기록 추가 응답 상태 코드: ${response.statusCode}');
      print('방문 기록 추가 응답 본문: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('서버 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Visit history error: $e');
      throw Exception('Failed to add visit history: $e');
    }
  }
  // 방문 기록 조회
  Future<List<VisitHistory>> getVisitHistories({String? category}) async {
    try {
      final token = await _getToken();

      print('방문 기록 API 요청에 사용되는 토큰: $token');

      if (token == null) {
        throw Exception('Authentication required');
      }

      String authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

      String url = baseUrl;
      if (category != null && category.isNotEmpty && category != '전체') {
        url += '?category=$category';
      }

      print('방문 기록 API 요청 URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': authHeader
        },
      );

      print('방문 기록 API 응답 상태 코드: ${response.statusCode}');
      print('방문 기록 API 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        // 여기가 수정된 부분: 응답을 Map으로 파싱한 다음 'data' 필드를 추출
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final List<dynamic> jsonList = jsonResponse['data'];
        return jsonList.map((json) => VisitHistory.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get visit histories: ${response.body}');
      }
    } catch (e) {
      print('방문 기록 가져오기 오류: $e');
      throw Exception('Error getting visit histories: $e');
    }
  }


  // 카테고리별 방문 기록 조회
  Future<List<VisitHistory>> getVisitHistoriesByCategory(String category) async {
    final histories = await getVisitHistories();
    return histories.where((h) => h.category == category).toList();
  }

  // 자주 방문한 장소 조회
  Future<List<VisitHistory>> getFrequentlyVisitedPlaces({int limit = 5}) async {
    final histories = await getVisitHistories();

    // 방문 횟수로 정렬
    histories.sort((a, b) => b.visitCount.compareTo(a.visitCount));

    return histories.take(limit).toList();
  }

  // 최근 방문한 장소 조회
  Future<List<VisitHistory>> getRecentlyVisitedPlaces({int limit = 5}) async {
    final histories = await getVisitHistories();

    // 날짜로 정렬 (이미 정렬되어 있지만 확실히 하기 위해)
    histories.sort((a, b) => b.visitDate.compareTo(a.visitDate));

    return histories.take(limit).toList();
  }

  // 카테고리별 통계 조회
  Future<Map<String, int>> getCategoryStats() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
        headers: {
          'Authorization': 'Bearer $token'
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonMap = jsonDecode(response.body);
        return jsonMap.map((key, value) => MapEntry(key, value as int));
      } else {
        throw Exception('Failed to get category stats: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting category stats: $e');
    }
  }

  // 방문 기록 삭제
  Future<void> deleteVisitHistory(String id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Authorization': 'Bearer $token'
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete visit history: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting visit history: $e');
    }
  }

  // 모든 방문 기록 삭제
  Future<void> deleteAllVisitHistories() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.delete(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token'
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete all visit histories: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting all visit histories: $e');
    }
  }
  // 모든 방문 기록 삭제
  Future<void> clearAllVisitHistories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      print('모든 방문 기록 삭제 실패: $e');
      rethrow;
    }
  }
}