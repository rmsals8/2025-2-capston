// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class AuthProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;
  bool _isFirstLogin = false;  // 첫 로그인 상태 추가
  final baseUrl = dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8081/api/v1';
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;
  bool get isFirstLogin => _isFirstLogin;  // 첫 로그인 getter 추가

  AuthProvider() {
    _checkLoginStatus();
  }
  
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('access_token');
    return token;
  }
  
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getString('access_token') != null;
    _isFirstLogin = prefs.getBool('is_first_login') ?? false;  // 첫 로그인 상태 로드
    notifyListeners();
  }

  Future<void> login({
  required String email,
  required String password,
  bool rememberMe = false,
}) async {
  try {
    _setLoading(true);

    // 실제 API 호출 구현
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // 서버에서 받은 실제 토큰 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', data['accessToken']);
      await prefs.setString('refresh_token', data['refreshToken']);
      await prefs.setString('user_id', data['userId']);
      await prefs.setString('user_email', email);
      await prefs.setString('user_name', data['name']);
      
      if (rememberMe) {
        await prefs.setBool('remember_me', true);
      }

      // 첫 로그인 여부 확인 (서버에서 제공하거나 로컬 로직으로 판단)
      final isFirstTimeUser = data['isFirstTimeUser'] ?? false;
      await prefs.setBool('is_first_login', isFirstTimeUser);
      
      _isLoggedIn = true;
      _isFirstLogin = isFirstTimeUser;
      
      notifyListeners();
    } else {
      // 로그인 실패 처리
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? '로그인에 실패했습니다');
    }
  } catch (e) {
    _setError('로그인에 실패했습니다: ${e.toString()}');
  } finally {
    _setLoading(false);
  }
}

  // 첫 로그인 상태 업데이트 메서드 추가
// 첫 로그인 상태 업데이트 메서드 수정
Future<void> updateFirstLoginStatus(bool isFirst) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // 현재 로그인된 사용자 ID 가져오기
    final userId = prefs.getString('user_id');
    
    // 일반 첫 로그인 상태 업데이트
    await prefs.setBool('is_first_login', isFirst);
    _isFirstLogin = isFirst;
    
    // 사용자별 첫 로그인 상태도 업데이트 (userId가 있는 경우)
    if (userId != null && userId.isNotEmpty) {
      final String userFirstLoginKey = 'user_first_login_$userId';
      await prefs.setBool(userFirstLoginKey, isFirst);
      print('사용자 $userId의 첫 로그인 상태를 $isFirst로 업데이트');
    }
    
    notifyListeners();
  } catch (e) {
    print('첫 로그인 상태 업데이트 오류: $e');
  }
}

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      _setLoading(true);

      // TODO: 실제 회원가입 API 호출 구현
      // 임시 구현: 회원가입 후 자동 로그인
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', 'dummy_token');
      await prefs.setString('user_id', email.split('@')[0]);
      await prefs.setString('user_email', email);
      await prefs.setString('user_name', name);
      
      // 신규 가입은 항상 첫 로그인으로 설정
      await prefs.setBool('is_first_login', true);

      _isLoggedIn = true;
      _isFirstLogin = true;
      
      notifyListeners();
    } catch (e) {
      _setError('회원가입에 실패했습니다');
    } finally {
      _setLoading(false);
    }
  }

// 로그아웃 메서드 수정
Future<void> logout() async {
  try {
    _setLoading(true);

    final prefs = await SharedPreferences.getInstance();
    
    // 현재 사용자 ID 저장 (나중에 사용)
    final userId = prefs.getString('user_id');

    // 모든 사용자 관련 정보 삭제
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('remember_me');
    
    // 첫 로그인 상태는 제거 (다음 로그인 시 사용자별 상태 사용)
    await prefs.remove('is_first_login');

    _isLoggedIn = false;
    _isFirstLogin = false;
    notifyListeners();
  } catch (e) {
    _setError('로그아웃에 실패했습니다');
  } finally {
    _setLoading(false);
  }
}

  Future<void> refreshToken() async {
    try {
      _setLoading(true);

      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');

      if (refreshToken == null) {
        throw Exception('Refresh token not found');
      }

      // TODO: API 호출하여 토큰 갱신

    } catch (e) {
      _setError('토큰 갱신에 실패했습니다');
      await logout();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}