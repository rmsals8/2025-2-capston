// lib/services/visit_history_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/visit_history.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as Math;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VisitHistoryService {
  static String? _cachedToken;
  static DateTime? _tokenTime;
  static const String _storageKey = 'visit_history';
  final Uuid _uuid = const Uuid();

  // 캐시 관련 변수들 추가
  static List<VisitHistory>? _cachedHistories;
  static DateTime? _cacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 5); // 5분간 캐시 유지

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

  // 캐시 확인 메서드
  bool _isCacheValid() {
    return _cachedHistories != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).compareTo(_cacheTimeout) < 0;
  }

  // 캐시 업데이트 메서드
  void _updateCache(List<VisitHistory> histories) {
    _cachedHistories = histories;
    _cacheTime = DateTime.now();
  }

  // 캐시 무효화 메서드
  void _invalidateCache() {
    _cachedHistories = null;
    _cacheTime = null;
  }

  // 페이징 처리된 방문 기록 조회 - 최적화됨
  Future<Map<String, dynamic>> getVisitHistoriesPaged({
    String? category,
    int page = 0,
    int size = 10,
  }) async {
    try {
      final token = await _getToken();

      print('페이징 방문 기록 API 요청에 사용되는 토큰: ${token != null ? "있음" : "없음"}');

      if (token == null) {
        throw Exception('Authentication required');
      }

      String authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

      String url = '$baseUrl/paged?page=$page&size=$size';
      if (category != null && category.isNotEmpty && category != '전체') {
        url += '&category=${Uri.encodeComponent(category)}';
      }

      print('페이징 방문 기록 API 요청 URL: $url');

      // 타임아웃 설정 추가 - 매우 중요!
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10)); // 10초 타임아웃

      print('페이징 방문 기록 API 응답 상태 코드: ${response.statusCode}');
      print('페이징 방문 기록 API 응답 시간: ${DateTime.now()}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 200 && jsonResponse['data'] != null) {
          final Map<String, dynamic> pageInfo = jsonResponse['data'];
          final List<dynamic> historyList = pageInfo['content'] ?? [];

          // 방문 기록 객체로 변환
          final List<VisitHistory> histories = historyList
              .map((item) => VisitHistory.fromJson(item))
              .toList();

          // 첫 페이지면 캐시 업데이트
          if (page == 0 && (category == null || category == '전체')) {
            _updateCache(histories);
          }

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
      } else if (response.statusCode == 408) {
        throw Exception('서버 응답 시간 초과');
      } else {
        throw Exception('방문 기록을 가져오는데 실패했습니다: ${response.statusCode}');
      }
    } catch (e) {
      print('페이징 방문 기록 가져오기 오류: $e');

      // 타임아웃 에러인 경우 더 구체적인 메시지
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답이 너무 느립니다. 다시 시도해주세요.');
      }

      throw Exception('페이징 방문 기록 조회 중 오류 발생: $e');
    }
  }

  // 방문 기록 추가 - 최적화됨
  Future<void> addVisitHistory(String placeName, String placeId, String category,
      double latitude, double longitude, String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      print('방문 기록 추가 시작: $placeName');

      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final data = {
        'placeName': placeName,
        'placeId': placeId,
        'category': category,
        'latitude': latitude,
        'longitude': longitude,
        'address': address
      };

      final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

      // 타임아웃 설정 추가
      final response = await http.post(
        Uri.parse('${baseUrl}/add'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader,
        },
        body: json.encode(data),
      ).timeout(const Duration(seconds: 10)); // 10초 타임아웃

      print('방문 기록 추가 응답 상태 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        // 성공 시 캐시 무효화
        _invalidateCache();
        print('방문 기록 추가 성공, 캐시 무효화됨');
      } else {
        throw Exception('서버 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Visit history error: $e');

      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답이 너무 느립니다. 다시 시도해주세요.');
      }

      throw Exception('Failed to add visit history: $e');
    }
  }

  // 방문 기록 조회 - 캐시 사용
  Future<List<VisitHistory>> getVisitHistories({String? category}) async {
    try {
      // 캐시 확인 (카테고리 필터가 없을 때만)
      if ((category == null || category == '전체') && _isCacheValid()) {
        print('캐시에서 방문 기록 반환');
        return _cachedHistories!;
      }

      final token = await _getToken();

      print('방문 기록 API 요청에 사용되는 토큰: ${token != null ? "있음" : "없음"}');

      if (token == null) {
        throw Exception('Authentication required');
      }

      String authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

      String url = baseUrl;
      if (category != null && category.isNotEmpty && category != '전체') {
        url += '?category=${Uri.encodeComponent(category)}';
      }

      print('방문 기록 API 요청 URL: $url');

      // 타임아웃 설정 추가
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10)); // 10초 타임아웃

      print('방문 기록 API 응답 상태 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final List<dynamic> jsonList = jsonResponse['data'];
        final List<VisitHistory> histories = jsonList.map((json) => VisitHistory.fromJson(json)).toList();

        // 카테고리 필터가 없으면 캐시 업데이트
        if (category == null || category == '전체') {
          _updateCache(histories);
        }

        return histories;
      } else if (response.statusCode == 408) {
        throw Exception('서버 응답 시간 초과');
      } else {
        throw Exception('Failed to get visit histories: ${response.statusCode}');
      }
    } catch (e) {
      print('방문 기록 가져오기 오류: $e');

      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답이 너무 느립니다. 다시 시도해주세요.');
      }

      throw Exception('Error getting visit histories: $e');
    }
  }

  // 카테고리별 방문 기록 조회
  Future<List<VisitHistory>> getVisitHistoriesByCategory(String category) async {
    final histories = await getVisitHistories();
    return histories.where((h) => h.category == category).toList();
  }

  // 자주 방문한 장소 조회 - 캐시 활용
  Future<List<VisitHistory>> getFrequentlyVisitedPlaces({int limit = 5}) async {
    final histories = await getVisitHistories();

    // 방문 횟수로 정렬
    histories.sort((a, b) => b.visitCount.compareTo(a.visitCount));

    return histories.take(limit).toList();
  }

  // 최근 방문한 장소 조회 - 캐시 활용
  Future<List<VisitHistory>> getRecentlyVisitedPlaces({int limit = 5}) async {
    final histories = await getVisitHistories();

    // 날짜로 정렬 (이미 정렬되어 있지만 확실히 하기 위해)
    histories.sort((a, b) => b.visitDate.compareTo(a.visitDate));

    return histories.take(limit).toList();
  }

  // 카테고리별 통계 조회 - 최적화됨
  Future<Map<String, int>> getCategoryStats() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      // 타임아웃 설정 추가
      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10)); // 10초 타임아웃

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonMap = jsonDecode(response.body);
        return jsonMap.map((key, value) => MapEntry(key, value as int));
      } else {
        throw Exception('Failed to get category stats: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답이 너무 느립니다. 다시 시도해주세요.');
      }
      throw Exception('Error getting category stats: $e');
    }
  }

  // 방문 기록 삭제 - 최적화됨
  Future<void> deleteVisitHistory(String id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      // 타임아웃 설정 추가
      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10)); // 10초 타임아웃

      if (response.statusCode == 200) {
        // 성공 시 캐시 무효화
        _invalidateCache();
        print('방문 기록 삭제 성공, 캐시 무효화됨');
      } else {
        throw Exception('Failed to delete visit history: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답이 너무 느립니다. 다시 시도해주세요.');
      }
      throw Exception('Error deleting visit history: $e');
    }
  }

  // 모든 방문 기록 삭제 - 최적화됨
  Future<void> deleteAllVisitHistories() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      // 타임아웃 설정 추가
      final response = await http.delete(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10)); // 10초 타임아웃

      if (response.statusCode == 200) {
        // 성공 시 캐시 무효화
        _invalidateCache();
        print('모든 방문 기록 삭제 성공, 캐시 무효화됨');
      } else {
        throw Exception('Failed to delete all visit histories: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답이 너무 느립니다. 다시 시도해주세요.');
      }
      throw Exception('Error deleting all visit histories: $e');
    }
  }

  // 모든 방문 기록 삭제
  Future<void> clearAllVisitHistories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);

      // 캐시도 무효화
      _invalidateCache();
    } catch (e) {
      print('모든 방문 기록 삭제 실패: $e');
      rethrow;
    }
  }

  // 캐시 상태 확인 메서드 (디버깅용)
  Map<String, dynamic> getCacheStatus() {
    return {
      'hasCachedData': _cachedHistories != null,
      'cacheSize': _cachedHistories?.length ?? 0,
      'cacheTime': _cacheTime?.toString(),
      'isValid': _isCacheValid(),
    };
  }
}