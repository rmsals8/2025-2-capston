import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screens/auth/kakao_login_webview.dart';
import '/screens/main_navigation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' ;

class KakaoImageButton extends StatelessWidget {
  final Function(String)? onLoginSuccess;
  final Function(String)? onLoginError;
  final kakaoClientId = dotenv.env['KAKAO_CLIENT_ID'] ?? '357d3401893dc5c9cbefc83bb65df4ee';
  final kakaoCallbackUrl = dotenv.env['KAKAO_CALLBACK_URL'] ?? 'http://localhost:8080/api/oauth2/callback/kakao';
  final redirectUrl = dotenv.env['KAKAO_CALLBACK_URL'] ?? 'http://localhost:8080/api/oauth2/callback/kakao';
  KakaoImageButton({
    Key? key,
    this.onLoginSuccess,
    this.onLoginError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      height: 48, // 이미지 높이에 맞게 조정 가능
      child: GestureDetector(
        onTap: () => _handleLogin(context),
        child: Image.asset(
          'assets/icons/kakao_login_large_wide.png', // 이미지 경로
          fit: BoxFit.fitWidth,
          width: double.infinity,
        ),
      ),
    );
  }

  void _handleLogin(BuildContext context) async {
    try {
      final loginUrl = _getAuthUrl();
      // final redirectUrl = 'http://localhost:8080/api/oauth2/callback/kakao';

      print('인증 URL: $loginUrl');
      print('리디렉션 URL: $redirectUrl');

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KakaoLoginWebView(
            loginUrl: loginUrl,
            redirectUrl: redirectUrl,
            loginType: 'kakao',
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
      } else {
        // 로그인 실패 또는 취소
        onLoginError?.call('로그인이 취소되었습니다.');
      }
    } catch (e) {
      print('로그인 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 중 오류가 발생했습니다: $e')),
        );
        onLoginError?.call('로그인 중 오류가 발생했습니다: $e');
      }
    }
  }

  String _getAuthUrl() {

    final redirectUri = Uri.encodeComponent(kakaoCallbackUrl);
    return 'https://kauth.kakao.com/oauth/authorize'
        '?client_id=$kakaoClientId'
        '&redirect_uri=$redirectUri'
        '&response_type=code';
  }

  Future<void> _saveTokens(
      String accessToken,
      String refreshToken,
      {String? userId, String? userName, String? userEmail}
      ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);

    // Also save user ID if provided
    if (userId != null && userId.isNotEmpty) {
      await prefs.setString('user_id', userId);
    } else {
      // Generate a default user ID based on login type
      final defaultId = 'kakao_user';
      await prefs.setString('user_id', '${defaultId}_${DateTime.now().millisecondsSinceEpoch}');
    }

    // Save user email if provided or generate a placeholder
    if (userEmail != null && userEmail.isNotEmpty) {
      await prefs.setString('user_email', userEmail);
    } else {
      final id = prefs.getString('user_id') ?? 'unknown';
      await prefs.setString('user_email', '$id@kakao.com');
    }

    // Save user name if provided or use a default
    if (userName != null && userName.isNotEmpty) {
      await prefs.setString('user_name', userName);
    } else {
      // Use platform name as prefix
      await prefs.setString('user_name', 'Kakao 사용자');
    }

    print('Social login successful! User info saved:');
    print('- ID: ${prefs.getString('user_id')}');
    print('- Name: ${prefs.getString('user_name')}');
    print('- Email: ${prefs.getString('user_email')}');
  }
}