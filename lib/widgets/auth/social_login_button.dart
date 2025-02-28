import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../screens/auth/kakao_login_webview.dart';
import '/screens/main_navigation.dart';  // MainNavigation import 추가
enum SocialLoginType {
  kakao,
  naver,
}

class SocialLoginButton extends StatelessWidget {
  final SocialLoginType type;
  final Function(String) onLoginSuccess;
  final Function(String)? onLoginError;
  Future<void> _saveTokens(
      String accessToken,
      String refreshToken,
      {String? userId, String? userName, String? userEmail}
      ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);

    // Social platform type
    final platformType = type == SocialLoginType.kakao ? 'Kakao' : 'Naver';

    // Also save user ID if provided
    if (userId != null && userId.isNotEmpty) {
      await prefs.setString('user_id', userId);
    } else {
      // Generate a default user ID based on login type
      final defaultId = type == SocialLoginType.kakao ? 'kakao_user' : 'naver_user';
      await prefs.setString('user_id', '${defaultId}_${DateTime.now().millisecondsSinceEpoch}');
    }

    // Save user email if provided or generate a placeholder
    if (userEmail != null && userEmail.isNotEmpty) {
      await prefs.setString('user_email', userEmail);
    } else {
      final id = prefs.getString('user_id') ?? 'unknown';
      await prefs.setString('user_email', '$id@${platformType.toLowerCase()}.com');
    }

    // Save user name if provided or use a default
    if (userName != null && userName.isNotEmpty) {
      await prefs.setString('user_name', userName);
    } else {
      // Use platform name as prefix
      await prefs.setString('user_name', '$platformType 사용자');
    }

    print('Social login successful! User info saved:');
    print('- ID: ${prefs.getString('user_id')}');
    print('- Name: ${prefs.getString('user_name')}');
    print('- Email: ${prefs.getString('user_email')}');
  }
  const SocialLoginButton({
    Key? key,
    required this.type,
    required this.onLoginSuccess,
    this.onLoginError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: () => _handleLogin(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: _getColor(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              _getIcon(),
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 12),
            Text(
              _getText(),
              style: TextStyle(
                color: _getTextColor(),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogin(BuildContext context) async {
    try {
      final loginUrl = _getAuthUrl();

      // 카카오와 네이버의 콜백 URL을 각각 올바르게 설정
      final redirectUrl = type == SocialLoginType.kakao
          ? 'http://localhost:8080/api/oauth2/callback/kakao'  // 카카오는 v1 없음
          : 'http://localhost:8080/api/v1/oauth2/callback/naver';  // 네이버는 v1 있음

      print('인증 URL: $loginUrl');
      print('리디렉션 URL: $redirectUrl');

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KakaoLoginWebView(
            loginUrl: loginUrl,
            redirectUrl: redirectUrl,
            loginType: type == SocialLoginType.kakao ? 'kakao' : 'naver',
          ),
        ),
      );

      // 로그인 성공 후 메인 화면으로 이동
      if (result == true) {
        if (context.mounted) {
          // 토큰 저장 확인
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          print('저장된 토큰: $token');

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigation()),
          );
        }
      }
    } catch (e) {
      print('로그인 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  String _getAuthUrl() {
    switch (type) {
      case SocialLoginType.kakao:
        final redirectUri = Uri.encodeComponent('http://localhost:8080/api/oauth2/callback/kakao');
        return 'https://kauth.kakao.com/oauth/authorize'
            '?client_id=357d3401893dc5c9cbefc83bb65df4ee'  // REST API 키로 변경
            '&redirect_uri=$redirectUri'
            '&response_type=code';
      case SocialLoginType.naver:
        final state = DateTime.now().millisecondsSinceEpoch.toString();
        return 'https://nid.naver.com/oauth2.0/authorize'
            '?client_id=3fsFDFBv3hFuJkDoYMva'
            '&response_type=code'
            '&redirect_uri=${Uri.encodeComponent('http://localhost:8080/api/v1/oauth2/callback/naver')}'
            '&state=$state';
    }
  }
  String _getText() {
    switch (type) {
      case SocialLoginType.kakao:
        return '카카오로 계속하기';
      case SocialLoginType.naver:
        return '네이버로 계속하기';
    }
  }

  Color _getColor() {
    switch (type) {
      case SocialLoginType.kakao:
        return const Color(0xFFFEE500);
      case SocialLoginType.naver:
        return const Color(0xFF03C75A);
    }
  }

  Color _getTextColor() {
    switch (type) {
      case SocialLoginType.kakao:
        return Colors.black87;
      case SocialLoginType.naver:
        return Colors.white;
    }
  }

  String _getIcon() {
    switch (type) {
      case SocialLoginType.kakao:
        return 'assets/icons/kakao.png';
      case SocialLoginType.naver:
        return 'assets/icons/naver.png';
    }
  }
}