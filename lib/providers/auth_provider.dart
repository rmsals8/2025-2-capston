// lib/providers/auth_provider.dart - 수정된 버전
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

import '../services/navigation_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;
  bool _isFirstLogin = false;
  final baseUrl = dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8081/api/v1';

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;
  bool get isFirstLogin => _isFirstLogin;

  // ✅ 기본 생성자에서는 초기화하지 않음
  AuthProvider();

  // ✅ 새로운 초기화 메서드 추가
  Future<void> initializeAuth() async {
    print('AuthProvider 초기화 시작');
    await _checkLoginStatus();
    print('AuthProvider 초기화 완료 - 로그인 상태: $_isLoggedIn');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('access_token');
    print('토큰 조회: ${token != null ? "존재" : "없음"}');
    return token;
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('access_token');
      final String? refreshToken = prefs.getString('refresh_token');

      print('로그인 상태 확인 - 토큰: ${token != null ? "존재" : "없음"}');

      if (token != null && token.isNotEmpty) {
        // ✅ 토큰 유효성 검증 (선택사항)
        bool isValid = await _validateToken(token);

        if (isValid) {
          _isLoggedIn = true;
          _isFirstLogin = prefs.getBool('is_first_login') ?? false;
          print('유효한 토큰으로 로그인 상태 설정 완료');
        } else {
          // 토큰이 유효하지 않으면 로그아웃 처리
          print('토큰이 유효하지 않음, 로그아웃 처리');
          await _clearAuthData();
        }
      } else {
        // 토큰이 없으면 로그아웃 상태
        _isLoggedIn = false;
        _isFirstLogin = false;
        print('토큰이 없어 로그아웃 상태로 설정');
      }

      notifyListeners();
    } catch (e) {
      print('로그인 상태 확인 중 오류: $e');
      _isLoggedIn = false;
      _isFirstLogin = false;
      notifyListeners();
    }
  }

  // ✅ 토큰 유효성 검증 메서드 (선택사항)
  Future<bool> _validateToken(String token) async {
    try {
      // 간단한 프로필 API 호출로 토큰 유효성 확인
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'), // 프로필 조회 API (실제 엔드포인트에 맞게 수정)
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10)); // 타임아웃 설정

      if (response.statusCode == 200) {
        print('토큰 유효성 검증 성공');
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print('토큰 유효성 검증 실패 - 인증 오류');
        return false;
      } else {
        print('토큰 유효성 검증 - 예상치 못한 응답: ${response.statusCode}');
        // 네트워크 오류 등의 경우 토큰을 유효한 것으로 간주 (보수적 접근)
        return true;
      }
    } catch (e) {
      print('토큰 유효성 검증 중 오류: $e');
      // 네트워크 오류의 경우 토큰을 유효한 것으로 간주
      return true;
    }
  }

  // ✅ 인증 데이터 정리 메서드
  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');

    _isLoggedIn = false;
    _isFirstLogin = false;
  }

  Future<void> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      _setLoading(true);

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

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['accessToken']);
        await prefs.setString('refresh_token', data['refreshToken']);
        await prefs.setString('user_id', data['userId']);
        await prefs.setString('user_email', email);
        await prefs.setString('user_name', data['name']);

        if (rememberMe) {
          await prefs.setBool('remember_me', true);
        }

        final isFirstTimeUser = data['isFirstTimeUser'] ?? false;
        await prefs.setBool('is_first_login', isFirstTimeUser);

        // ✅ 로그인 상태 즉시 업데이트
        _isLoggedIn = true;
        _isFirstLogin = isFirstTimeUser;

        print('로그인 성공 - 상태 업데이트 완료');
        notifyListeners();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '로그인에 실패했습니다');
      }
    } catch (e) {
      _setError('로그인에 실패했습니다: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateFirstLoginStatus(bool isFirst) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      await prefs.setBool('is_first_login', isFirst);
      _isFirstLogin = isFirst;

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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', 'dummy_token');
      await prefs.setString('user_id', email.split('@')[0]);
      await prefs.setString('user_email', email);
      await prefs.setString('user_name', name);

      await prefs.setBool('is_first_login', true);

      // ✅ 회원가입 후 로그인 상태 즉시 업데이트
      _isLoggedIn = true;
      _isFirstLogin = true;

      notifyListeners();
    } catch (e) {
      _setError('회원가입에 실패했습니다');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      _setLoading(true);

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      // ✅ 인증 데이터 정리
      await _clearAuthData();

      // 기타 데이터 정리
      await prefs.remove('remember_me');
      await prefs.remove('user_category_preferences');

      // ✅ 로그아웃 상태 즉시 업데이트
      _isLoggedIn = false;
      _isFirstLogin = false;

      print('로그아웃 완료 - 상태 업데이트');
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
      // 갱신 실패 시 로그아웃 처리
      // await logout();

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