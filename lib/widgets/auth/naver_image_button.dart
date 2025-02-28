import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screens/auth/kakao_login_webview.dart';
import '/screens/main_navigation.dart';

class NaverImageButton extends StatelessWidget {
  final Function(String)? onLoginSuccess;
  final Function(String)? onLoginError;

  const NaverImageButton({
    Key? key,
    this.onLoginSuccess,
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
          backgroundColor: const Color(0xFF03C75A), // 네이버 브랜드 색상
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 네이버 로고 이미지 (왼쪽 끝에 배치)
            Positioned(
              left: 12,
              child: Image.asset(
                'assets/icons/naver2.png',
                width: 24,
                height: 24,
              ),
            ),
            // 텍스트를 정확히 중앙에 배치
            const Center(
              child: Text(
                '네이버 로그인',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 기존의 _handleLogin, _getAuthUrl, _saveTokens 메서드는 그대로 유지
  void _handleLogin(BuildContext context) async {
    try {
      final loginUrl = _getAuthUrl();
      final redirectUrl = 'http://localhost:8080/api/v1/oauth2/callback/naver';

      print('인증 URL: $loginUrl');
      print('리디렉션 URL: $redirectUrl');

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KakaoLoginWebView(
            loginUrl: loginUrl,
            redirectUrl: redirectUrl,
            loginType: 'naver',
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
    final state = DateTime.now().millisecondsSinceEpoch.toString();
    return 'https://nid.naver.com/oauth2.0/authorize'
        '?client_id=3fsFDFBv3hFuJkDoYMva'
        '&response_type=code'
        '&redirect_uri=${Uri.encodeComponent('http://localhost:8080/api/v1/oauth2/callback/naver')}'
        '&state=$state';
  }

  Future<void> _saveTokens(
      String accessToken,
      String refreshToken,
      {String? userId, String? userName, String? userEmail}
      ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);

    // 기존 토큰 저장 로직 그대로 유지
    if (userId != null && userId.isNotEmpty) {
      await prefs.setString('user_id', userId);
    } else {
      final defaultId = 'naver_user';
      await prefs.setString('user_id', '${defaultId}_${DateTime.now().millisecondsSinceEpoch}');
    }

    if (userEmail != null && userEmail.isNotEmpty) {
      await prefs.setString('user_email', userEmail);
    } else {
      final id = prefs.getString('user_id') ?? 'unknown';
      await prefs.setString('user_email', '$id@naver.com');
    }

    if (userName != null && userName.isNotEmpty) {
      await prefs.setString('user_name', userName);
    } else {
      await prefs.setString('user_name', 'Naver 사용자');
    }

    print('Social login successful! User info saved:');
    print('- ID: ${prefs.getString('user_id')}');
    print('- Name: ${prefs.getString('user_name')}');
    print('- Email: ${prefs.getString('user_email')}');
  }
}