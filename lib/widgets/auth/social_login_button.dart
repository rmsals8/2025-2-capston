import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '/screens/main_navigation.dart';  // MainNavigation import 추가
enum SocialLoginType {
  kakao,
  naver,
}

class SocialLoginButton extends StatelessWidget {
  final SocialLoginType type;
  final Function(String) onLoginSuccess;
  final Function(String)? onLoginError;
// social_login_button.dart에 추가
  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
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
      final Uri authUri = Uri.parse(_getAuthUrl());
      if (await canLaunchUrl(authUri)) {
        await launchUrl(
          authUri,
          mode: LaunchMode.inAppWebView,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );

        // 로그인 성공 후 메인 화면으로 이동
        if (context.mounted) {  // context가 유효한지 확인
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigation()),
          );
        }
      }
    } catch (e) {
      print('Login error: $e');
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
        final redirectUri = Uri.encodeComponent('https://43b2-203-250-67-107.ngrok-free.app/api/oauth2/callback/kakao');
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