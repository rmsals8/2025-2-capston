import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;

  AuthProvider() {
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getString('access_token') != null;
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
      if (rememberMe) {
        await prefs.setBool('remember_me', true);
      }

      _isLoggedIn = true;
      notifyListeners();
    } catch (e) {
      _setError('로그인에 실패했습니다');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      _setLoading(true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');

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