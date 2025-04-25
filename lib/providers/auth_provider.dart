// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;
  bool _isFirstLogin = false;  // 첫 로그인 상태 추가

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

      // TODO: API 호출하여 로그인 처리
      // 임시로 토큰 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', 'dummy_token');

      // Also store user ID (in a real app, this would come from the server)
      // For demonstration, we'll use the email as the user ID
      await prefs.setString('user_id', email.split('@')[0]);

      // Store user email
      await prefs.setString('user_email', email);

      // Extract and store user name from email
      String nameFromEmail = email.split('@')[0];
      nameFromEmail = nameFromEmail
          .replaceAll('.', ' ')
          .replaceAll('_', ' ')
          .split(' ')
          .map((word) => word.isNotEmpty
          ? word[0].toUpperCase() + word.substring(1)
          : '')
          .join(' ');
      await prefs.setString('user_name', nameFromEmail);

      if (rememberMe) {
        await prefs.setBool('remember_me', true);
      }

      _isLoggedIn = true;
      _isFirstLogin = true;  // 로그인 성공 시 첫 로그인으로 간주
      
      // 첫 로그인 상태 저장
      await prefs.setBool('is_first_login', true);
      
      notifyListeners();
    } catch (e) {
      _setError('로그인에 실패했습니다');
    } finally {
      _setLoading(false);
    }
  }

  // 첫 로그인 상태 업데이트 메서드 추가
  Future<void> updateFirstLoginStatus(bool isFirst) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_first_login', isFirst);
      _isFirstLogin = isFirst;
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

  Future<void> logout() async {
    try {
      _setLoading(true);

      final prefs = await SharedPreferences.getInstance();

      // 모든 사용자 관련 정보 삭제
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await prefs.remove('remember_me');
      
      // 첫 로그인 상태는 유지 (다음 로그인에 대비)
      // await prefs.remove('is_first_login');

      _isLoggedIn = false;
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