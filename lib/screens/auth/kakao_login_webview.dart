import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KakaoLoginWebView extends StatefulWidget {
  final String loginUrl;
  final String redirectUrl;
  final String loginType; // 로그인 유형 추가 (kakao 또는 naver)

  const KakaoLoginWebView({
    Key? key,
    required this.loginUrl,
    required this.redirectUrl,
    this.loginType = 'kakao', // 기본값은 kakao로 설정
  }) : super(key: key);

  @override
  State<KakaoLoginWebView> createState() => _KakaoLoginWebViewState();
}

class _KakaoLoginWebViewState extends State<KakaoLoginWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // 리다이렉트 URL을 감지하여 토큰 추출
            if (request.url.startsWith(widget.redirectUrl)) {
              _handleRedirect(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.loginUrl));
  }

  void _handleRedirect(String url) async {
    // URL에서 인증 코드 추출
    Uri uri = Uri.parse(url);
    String? code = uri.queryParameters['code'];

    // 네이버의 경우 state 파라미터도 확인
    String? state = uri.queryParameters['state'];

    if (code != null) {
      // 인증 코드를 사용하여 백엔드에서 토큰 요청
      final response = await _getTokenFromBackend(code, state);

      if (response.isSuccess) {
        // 토큰 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', response.accessToken);
        await prefs.setString('refresh_token', response.refreshToken);

        if (mounted) {
          // 성공 메시지 표시 후 이전 화면으로 돌아가기
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인 성공!')),
          );
          Navigator.pop(context, true); // 로그인 성공 결과 반환
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('로그인 실패: ${response.error}')),
          );
          Navigator.pop(context, false);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증 코드를 받지 못했습니다')),
        );
        Navigator.pop(context, false);
      }
    }
  }

  Future<TokenResponse> _getTokenFromBackend(String code, String? state) async {
    try {
      print('인증 코드: $code');
      if (state != null) {
        print('네이버 state: $state');
      }

      // 카카오와 네이버에 따라 다른 URL 패턴 사용
      String tokenUrl;
      if (widget.loginType == 'kakao') {
        // 카카오는 v1 없음
        tokenUrl = 'http://10.0.2.2:8080/api/oauth2/callback/kakao/token';
      } else {
        // 네이버는 v1 있음
        tokenUrl = 'http://10.0.2.2:8080/api/v1/oauth2/callback/naver/token';
      }

      print('토큰 요청 URL: $tokenUrl');

      // GET 요청으로 변경 (서버에서 RequestParam으로 받음)
      final response = await http.post(
        Uri.parse('$tokenUrl?code=$code' + (state != null ? '&state=$state' : '')),
        headers: {'Content-Type': 'application/json'},
      );

      print('토큰 요청 응답 상태 코드: ${response.statusCode}');
      print('토큰 요청 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print('받은 액세스 토큰: ${data['accessToken']}');
        print('받은 리프레시 토큰: ${data['refreshToken']}');

        // 토큰 저장 확인용 로그
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['accessToken']);
        await prefs.setString('refresh_token', data['refreshToken']);
        print('토큰 저장 완료: ${prefs.getString('access_token')}');

        return TokenResponse(
          isSuccess: true,
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
        );
      } else {
        print('토큰 요청 실패: ${response.body}');
        return TokenResponse(
          isSuccess: false,
          error: response.body,
        );
      }
    } catch (e) {
      print('토큰 요청 오류: $e');
      return TokenResponse(
        isSuccess: false,
        error: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 유형에 따라 적절한 제목 가져오기
    String title = widget.loginType == 'kakao' ? '카카오 로그인' : '네이버 로그인';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class TokenResponse {
  final bool isSuccess;
  final String accessToken;
  final String refreshToken;
  final String? error;

  TokenResponse({
    required this.isSuccess,
    this.accessToken = '',
    this.refreshToken = '',
    this.error,
  });
}