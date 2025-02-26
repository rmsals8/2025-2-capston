// lib/services/visit_history_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/visit_history.dart';

class VisitHistoryService {
  static const String _storageKey = 'visit_history';
  final Uuid _uuid = const Uuid();

  // 방문 기록 저장
  Future<void> addVisitHistory(VisitHistory history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<VisitHistory> histories = await getVisitHistories();

      // 이미 동일한 장소에 방문 기록이 있는지 확인
      final existingIndex = histories.indexWhere((h) => h.placeId == history.placeId);

      if (existingIndex >= 0) {
        // 기존 기록 업데이트 (방문 횟수 증가)
        final existing = histories[existingIndex];
        histories[existingIndex] = existing.copyWith(
          visitDate: history.visitDate,
          visitCount: existing.visitCount + 1,
        );
      } else {
        // 새 방문 기록 생성
        final newHistory = history.copyWith(
          id: _uuid.v4(),
        );
        histories.add(newHistory);
      }

      // 날짜순으로 정렬
      histories.sort((a, b) => b.visitDate.compareTo(a.visitDate));

      // 저장
      await prefs.setString(
        _storageKey,
        jsonEncode(histories.map((h) => h.toJson()).toList()),
      );
    } catch (e) {
      print('방문 기록 저장 실패: $e');
      rethrow;
    }
  }

  // 모든 방문 기록 조회
  Future<List<VisitHistory>> getVisitHistories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_storageKey);

      if (jsonStr == null || jsonStr.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((json) => VisitHistory.fromJson(json)).toList();
    } catch (e) {
      print('방문 기록 조회 실패: $e');
      return [];
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

  // 방문 기록 삭제
  Future<void> deleteVisitHistory(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<VisitHistory> histories = await getVisitHistories();

      histories.removeWhere((h) => h.id == id);

      await prefs.setString(
        _storageKey,
        jsonEncode(histories.map((h) => h.toJson()).toList()),
      );
    } catch (e) {
      print('방문 기록 삭제 실패: $e');
      rethrow;
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