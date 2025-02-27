// lib/services/visit_history_service_with_cache.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/visit_history.dart';

class VisitHistoryService {
  static const String baseUrl = 'http://localhost:8080/api/v1/visit-histories';
  static const String _storageKey = 'visit_history';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // 방문 기록 추가
  Future<VisitHistory> addVisitHistory(
      String placeName,
      String placeId,
      String category,
      double latitude,
      double longitude,
      String address
      ) async {
    try {
      final token = await _getToken();

      // 로컬 데이터베이스에 저장 (오프라인 지원)
      final prefs = await SharedPreferences.getInstance();
      final List<VisitHistory> histories = await getVisitHistories();

      // 기존 방문 기록이 있는지 확인
      int existingIndex = histories.indexWhere((h) => h.placeId == placeId);
      VisitHistory visitHistory;

      if (existingIndex >= 0) {
        // 기존 기록 업데이트
        final existing = histories[existingIndex];
        visitHistory = VisitHistory(
            id: existing.id,
            placeName: placeName,
            placeId: placeId,
            category: category,
            latitude: latitude,
            longitude: longitude,
            address: address,
            visitDate: DateTime.now(),
            visitCount: existing.visitCount + 1
        );
        histories[existingIndex] = visitHistory;
      } else {
        // 새 기록 생성
        visitHistory = VisitHistory(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            placeName: placeName,
            placeId: placeId,
            category: category,
            latitude: latitude,
            longitude: longitude,
            address: address,
            visitDate: DateTime.now(),
            visitCount: 1
        );
        histories.add(visitHistory);
      }

      // 정렬 및 저장
      histories.sort((a, b) => b.visitDate.compareTo(a.visitDate));
      await prefs.setString(
          _storageKey,
          jsonEncode(histories.map((h) => h.toJson()).toList())
      );

      // 서버에도 저장 시도 (토큰이 있는 경우)
      if (token != null) {
        try {
          await http.post(
            Uri.parse(baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token'
            },
            body: jsonEncode({
              'placeName': placeName,
              'placeId': placeId,
              'category': category,
              'latitude': latitude,
              'longitude': longitude,
              'address': address
            }),
          );
        } catch (e) {
          // 서버 저장 실패는 무시 (로컬 저장은 이미 완료)
          print('Server sync failed: $e');
        }
      }

      return visitHistory;
    } catch (e) {
      throw Exception('Error adding visit history: $e');
    }
  }

  // 방문 기록 조회
  Future<List<VisitHistory>> getVisitHistories({String? category}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyString = prefs.getString(_storageKey);

      List<VisitHistory> histories = [];
      if (historyString != null) {
        final List<dynamic> jsonList = jsonDecode(historyString);
        histories = jsonList.map((json) => VisitHistory.fromJson(json)).toList();
      }

      // 카테고리 필터링
      if (category != null && category.isNotEmpty) {
        histories = histories.where((h) => h.category == category).toList();
      }

      // 서버 동기화 시도
      final token = await _getToken();
      if (token != null) {
        try {
          String url = baseUrl;
          if (category != null && category.isNotEmpty) {
            url += '?category=$category';
          }

          final response = await http.get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $token'},
          );

          if (response.statusCode == 200) {
            final List<dynamic> serverData = jsonDecode(response.body);
            final List<VisitHistory> serverHistories =
            serverData.map((json) => VisitHistory.fromJson(json)).toList();

            // 서버 데이터로 로컬 데이터 업데이트 (중복은 제거)
            await _syncHistories(serverHistories);

            // 업데이트된 로컬 데이터 반환
            return getVisitHistories(category: category);
          }
        } catch (e) {
          print('Server sync failed: $e');
          // 실패 시 로컬 데이터 반환
        }
      }

      return histories;
    } catch (e) {
      throw Exception('Error getting visit histories: $e');
    }
  }

  // 서버 데이터와 로컬 데이터 동기화
  Future<void> _syncHistories(List<VisitHistory> serverHistories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyString = prefs.getString(_storageKey);

      List<VisitHistory> localHistories = [];
      if (historyString != null) {
        final List<dynamic> jsonList = jsonDecode(historyString);
        localHistories = jsonList.map((json) => VisitHistory.fromJson(json)).toList();
      }

      // 서버 데이터와 로컬 데이터 병합
      for (var serverHistory in serverHistories) {
        int localIndex = localHistories.indexWhere((h) => h.id == serverHistory.id);

        if (localIndex >= 0) {
          // 로컬에 있는 데이터는 최신 데이터로 업데이트
          DateTime localDate = localHistories[localIndex].visitDate;
          DateTime serverDate = serverHistory.visitDate;

          if (serverDate.isAfter(localDate)) {
            localHistories[localIndex] = serverHistory;
          }
        } else {
          // 로컬에 없는 데이터는 추가
          localHistories.add(serverHistory);
        }
      }

      // 정렬 및 저장
      localHistories.sort((a, b) => b.visitDate.compareTo(a.visitDate));
      await prefs.setString(
          _storageKey,
          jsonEncode(localHistories.map((h) => h.toJson()).toList())
      );
    } catch (e) {
      print('Error syncing histories: $e');
    }
  }

  // 카테고리별 통계 조회
  Future<Map<String, int>> getCategoryStats() async {
    try {
      List<VisitHistory> histories = await getVisitHistories();
      Map<String, int> stats = {};

      for (var history in histories) {
        stats[history.category] = (stats[history.category] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      throw Exception('Error getting category stats: $e');
    }
  }

  // 방문 기록 삭제
  Future<void> deleteVisitHistory(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<VisitHistory> histories = await getVisitHistories();

      histories.removeWhere((h) => h.id == id);

      await prefs.setString(
          _storageKey,
          jsonEncode(histories.map((h) => h.toJson()).toList())
      );

      // 서버 동기화 시도
      final token = await _getToken();
      if (token != null) {
        try {
          await http.delete(
            Uri.parse('$baseUrl/$id'),
            headers: {'Authorization': 'Bearer $token'},
          );
        } catch (e) {
          print('Server sync failed: $e');
        }
      }
    } catch (e) {
      throw Exception('Error deleting visit history: $e');
    }
  }

  // 모든 방문 기록 삭제
  Future<void> deleteAllVisitHistories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);

      // 서버 동기화 시도
      final token = await _getToken();
      if (token != null) {
        try {
          await http.delete(
            Uri.parse(baseUrl),
            headers: {'Authorization': 'Bearer $token'},
          );
        } catch (e) {
          print('Server sync failed: $e');
        }
      }
    } catch (e) {
      throw Exception('Error deleting all visit histories: $e');
    }
  }

  // 자주 방문한 장소 조회
  Future<List<VisitHistory>> getFrequentlyVisitedPlaces({int limit = 5}) async {
    try {
      List<VisitHistory> histories = await getVisitHistories();

      // 방문 횟수로 정렬
      histories.sort((a, b) => b.visitCount.compareTo(a.visitCount));

      return histories.take(limit).toList();
    } catch (e) {
      throw Exception('Error getting frequently visited places: $e');
    }
  }

  // 최근 방문한 장소 조회
  Future<List<VisitHistory>> getRecentlyVisitedPlaces({int limit = 5}) async {
    try {
      List<VisitHistory> histories = await getVisitHistories();

      // 이미 날짜 순으로 정렬되어 있으므로 상위 몇 개만 반환
      return histories.take(limit).toList();
    } catch (e) {
      throw Exception('Error getting recently visited places: $e');
    }
  }
}