// lib/providers/user_preference_provider.dart 수정
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UserPreferenceProvider with ChangeNotifier {
  // 기본 키와 사용자별 키를 생성하기 위한 접두사
  final String _categoryPrefsKey = 'user_category_preferences';
  final String _userCategoryPrefsKeyPrefix = 'user_category_preferences_';
  
  bool _isLoading = false;
  String? _error;
  List<String> _preferredCategories = [];
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get preferredCategories => List.unmodifiable(_preferredCategories);
  
  // API 엔드포인트 기본값 설정
  String get baseUrl => dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8080/api/v1';
  
  UserPreferenceProvider() {
    _loadPreferences();
  }
  
  // 현재 사용자 ID 가져오기 헬퍼 메서드
  Future<String?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }
  
  // 사용자별 선호도 키 생성
  Future<String> _getUserSpecificKey() async {
    final userId = await _getCurrentUserId();
    return userId != null && userId.isNotEmpty
        ? '$_userCategoryPrefsKeyPrefix$userId'
        : _categoryPrefsKey; // 사용자 ID가 없으면 기본 키 사용
  }
  
  // 선호 카테고리 저장 (로컬 + 서버)
  Future<void> savePreferredCategories(List<String> categories) async {
    _setLoading(true);
    
    try {
      // 사용자별 키 가져오기
      final userSpecificKey = await _getUserSpecificKey();
      
      // 로컬 저장 (사용자별)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(userSpecificKey, categories);
      
      // 일반 키에도 저장 (호환성 유지)
      await prefs.setStringList(_categoryPrefsKey, categories);
      
      // 서버 저장 (사용자가 로그인 상태일 때만)
      final token = await _getToken();
      if (token != null) {
        await _saveToServer(categories, token);
      }
      
      _preferredCategories = List.from(categories);
      notifyListeners();
      
      print('카테고리 선호도 저장 완료: $userSpecificKey, 카테고리: ${categories.join(", ")}');
    } catch (e) {
      _setError('선호도 저장 실패: $e');
      print('카테고리 선호도 저장 실패: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // 서버에 선호도 저장
  Future<void> _saveToServer(List<String> categories, String token) async {
    try {
      final url = Uri.parse('$baseUrl/preferences/categories');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        },
        body: json.encode({
          'categories': categories,
        }),
      );
      
      if (response.statusCode != 200) {
        print('서버 선호도 저장 실패: ${response.statusCode} - ${response.body}');
      } else {
        print('서버 선호도 저장 성공');
      }
    } catch (e) {
      print('서버 선호도 저장 중 오류: $e');
      // 서버 저장 실패는 로컬 저장에 영향을 주지 않도록 예외를 던지지 않음
    }
  }
  
  // 선호 카테고리 가져오기 (사용자별 로컬 → 일반 로컬 → 서버 순)
  Future<List<String>> getPreferredCategories() async {
    _setLoading(true);
    
    try {
      // 사용자별 키 가져오기
      final userSpecificKey = await _getUserSpecificKey();
      final userId = await _getCurrentUserId();
      
      print('카테고리 선호도 로드 중: $userSpecificKey (사용자 ID: $userId)');
      
      // 로컬에서 사용자별 설정 가져오기
      final prefs = await SharedPreferences.getInstance();
      final userCategories = prefs.getStringList(userSpecificKey);
      
      if (userCategories != null && userCategories.isNotEmpty) {
        print('사용자별 카테고리 선호도 찾음: ${userCategories.join(", ")}');
        _preferredCategories = List.from(userCategories);
        return userCategories;
      }
      
      // 사용자별 설정이 없으면 일반 설정 확인
      final localCategories = prefs.getStringList(_categoryPrefsKey);
      if (localCategories != null && localCategories.isNotEmpty) {
        print('일반 카테고리 선호도 사용: ${localCategories.join(", ")}');
        
        // 일반 설정을 사용자별 설정으로 복사 (다음 로드를 위해)
        if (userId != null && userId.isNotEmpty) {
          await prefs.setStringList(userSpecificKey, localCategories);
        }
        
        _preferredCategories = List.from(localCategories);
        return localCategories;
      }
      
      // 로컬에 없으면 서버에서 가져오기 시도
      final token = await _getToken();
      if (token != null) {
        final serverCategories = await _loadFromServer(token);
        if (serverCategories.isNotEmpty) {
          print('서버 카테고리 선호도 사용: ${serverCategories.join(", ")}');
          
          // 서버에서 가져온 데이터 로컬에 캐싱 (사용자별)
          await prefs.setStringList(userSpecificKey, serverCategories);
          
          // 일반 키에도 저장 (호환성 유지)
          await prefs.setStringList(_categoryPrefsKey, serverCategories);
          
          _preferredCategories = List.from(serverCategories);
          return serverCategories;
        }
      }
      
      print('카테고리 선호도를 찾을 수 없음, 빈 목록 반환');
      _preferredCategories = [];
      return [];
    } catch (e) {
      _setError('선호도 불러오기 실패: $e');
      print('카테고리 선호도 로드 오류: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }
  
  // 서버에서 선호도 불러오기
  Future<List<String>> _loadFromServer(String token) async {
    try {
      final url = Uri.parse('$baseUrl/preferences/categories');
      final response = await http.get(
        url,
        headers: {
          'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('categories') && data['categories'] is List) {
          return List<String>.from(data['categories']);
        }
      }
      
      print('서버 선호도 불러오기 실패: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      print('서버 선호도 불러오기 중 오류: $e');
      return [];
    }
  }
  
  // 비동기 로드 - 초기화에 사용
  Future<void> _loadPreferences() async {
    try {
      await getPreferredCategories();
    } catch (e) {
      print('초기 선호도 로딩 오류: $e');
    }
  }
  
  // 모든 선호도 초기화
  Future<void> clearPreferences() async {
    _setLoading(true);
    
    try {
      final userId = await _getCurrentUserId();
      final userSpecificKey = await _getUserSpecificKey();
      
      final prefs = await SharedPreferences.getInstance();
      
      // 사용자별 선호도 제거
      await prefs.remove(userSpecificKey);
      
      // 일반 선호도도 제거 (다른 화면과의 호환성 유지)
      await prefs.remove(_categoryPrefsKey);
      
      // 서버 데이터도 삭제 시도
      final token = await _getToken();
      if (token != null) {
        await _clearFromServer(token);
      }
      
      _preferredCategories = [];
      notifyListeners();
      
      print('카테고리 선호도 초기화 완료: $userSpecificKey');
    } catch (e) {
      _setError('선호도 초기화 실패: $e');
      print('카테고리 선호도 초기화 실패: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // 서버 선호도 초기화
  Future<void> _clearFromServer(String token) async {
    try {
      final url = Uri.parse('$baseUrl/preferences/categories');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token',
        },
      );
      
      if (response.statusCode != 200) {
        print('서버 선호도 초기화 실패: ${response.statusCode} - ${response.body}');
      } else {
        print('서버 선호도 초기화 성공');
      }
    } catch (e) {
      print('서버 선호도 초기화 중 오류: $e');
    }
  }
  
  // 토큰 가져오기
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
  
  // 로딩 상태 설정
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  // 오류 설정
  void _setError(String message) {
    _error = message;
    notifyListeners();
  }
  
  // 오류 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }
}