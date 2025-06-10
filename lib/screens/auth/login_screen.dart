// lib/screens/auth/login_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:trip_helper/widgets/auth/custom_text_field.dart';
import 'package:trip_helper/screens/main_navigation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_helper/widgets/auth/kakao_image_button.dart';
import '../../providers/user_preference_provider.dart';
import '../../widgets/auth/modern_social_login_button.dart';
import '../../widgets/auth/naver_image_button.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onRegisterTap;
  final VoidCallback? onPasswordResetTap;

  const LoginScreen({
    Key? key,
    this.onRegisterTap,
    this.onPasswordResetTap,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _autoLogin = false;
  bool _obscurePassword = true;

  // 각각의 로딩 상태를 따로 관리
  bool _isEmailLoginLoading = false;  // 일반 로그인 로딩 상태
  bool _isKakaoLoginLoading = false;  // 카카오 로그인 로딩 상태

  final baseUrl = dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8081/api/v1';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleKakaoLogin() async {
    try {
      setState(() {
        _isKakaoLoginLoading = true;  // 카카오 로딩만 활성화
      });

      // 키 해시 직접 확인 (카카오 SDK 사용)
      try {
        final keyHash = await KakaoSdk.origin;
        print("=== 🔑 현재 사용 중인 키 해시 ===");
        print("KeyHash: $keyHash");
        print("패키지명: com.trip_helper.app");
        print("이 값을 카카오 개발자 콘솔에 등록하세요!");
        print("============================");

        // 사용자에게도 표시

      } catch (keyHashError) {
        print("키 해시 확인 실패: $keyHashError");
      }

      // 카카오 로그인 시도
      bool isInstalled = await isKakaoTalkInstalled();
      OAuthToken token;

      if (isInstalled) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      print('카카오 액세스 토큰: ${token.accessToken}');
      await _sendKakaoTokenToBackend(token.accessToken);

    } catch (error) {
      print('카카오 로그인 실패: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카카오 로그인 실패: $error')),
        );
      }

    } finally {
      if (mounted) {
        setState(() {
          _isKakaoLoginLoading = false;  // 카카오 로딩 비활성화
        });
      }
    }
  }

// 백엔드에 카카오 토큰 전송 - 최적화됨
  Future<void> _sendKakaoTokenToBackend(String kakaoToken) async {
    try {
      final apiUrl = kIsWeb
          ? 'http://localhost:8081/api/v1/auth/social/kakao'
          : '$baseUrl/auth/social/kakao';

      // 타임아웃 설정 추가
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'accessToken': kakaoToken,
        }),
      ).timeout(const Duration(seconds: 10)); // 10초 타임아웃

      print('카카오 백엔드 응답: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        final authResponse = json.decode(response.body);

        // 기본 토큰 저장만 먼저 수행
        await _saveBasicLoginData(authResponse);

        // 화면 이동을 먼저 하고
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigation()),
          );
        }

        // 선호도 로드는 백그라운드에서 수행
        _loadPreferencesInBackground(authResponse);

      } else {
        throw Exception('백엔드 인증 실패: ${response.body}');
      }
    } catch (e) {
      print('백엔드 토큰 전송 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 처리 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Schedule ',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w300,
                              color: Colors.grey[800],
                            ),
                          ),
                          const TextSpan(
                            text: 'Maker',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          const TextSpan(
                            text: '.',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '환영합니다',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // 이메일 입력
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: '이메일',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '이메일을 입력해주세요';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return '올바른 이메일 형식이 아닙니다';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 비밀번호 입력
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: '비밀번호',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey[400],
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '비밀번호를 입력해주세요';
                          }
                          if (value.length < 6) {
                            return '비밀번호는 6자 이상이어야 합니다';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 로그인 버튼 - 둘 중 하나라도 로딩 중이면 비활성화
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_isEmailLoginLoading || _isKakaoLoginLoading) ? null : _handleLogin,  // 둘 중 하나라도 로딩 중이면 비활성화
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _isEmailLoginLoading  // 일반 로그인 로딩만 체크
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 구분선
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[300])),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '또는',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey[300])),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 카카오 로그인 - 둘 중 하나라도 로딩 중이면 비활성화
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: (_isEmailLoginLoading || _isKakaoLoginLoading)
                            ? const Color(0xFFFEE500).withOpacity(0.5)  // 비활성화 시 투명도 50%
                            : const Color(0xFFFEE500),  // 활성화 시 원래 색상
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        onPressed: (_isEmailLoginLoading || _isKakaoLoginLoading) ? null : _handleKakaoLogin, // 둘 중 하나라도 로딩 중이면 비활성화
                        child: _isKakaoLoginLoading  // 카카오 로그인 로딩만 체크
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black54, // 카카오 노란색 배경에 맞는 색상
                            strokeWidth: 2,
                          ),
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble,
                              color: (_isEmailLoginLoading || _isKakaoLoginLoading)
                                  ? Colors.black.withOpacity(0.3)  // 비활성화 시 아이콘도 흐리게
                                  : Colors.black.withOpacity(0.85),  // 활성화 시 원래 색상
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '카카오로 계속하기',
                              style: TextStyle(
                                color: (_isEmailLoginLoading || _isKakaoLoginLoading)
                                    ? Colors.black.withOpacity(0.3)  // 비활성화 시 텍스트도 흐리게
                                    : Colors.black.withOpacity(0.85),  // 활성화 시 원래 색상
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 회원가입
                    // 회원가입 부분 아래에 비밀번호 찾기 버튼 추가
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '계정이 없으신가요?',
                          style: TextStyle(color: Colors.grey),
                        ),
                        TextButton(
                          onPressed: widget.onRegisterTap,
                          child: const Text(
                            '회원가입',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 12,
                          color: Colors.grey[300],
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        TextButton(
                          onPressed: widget.onPasswordResetTap,
                          child: const Text(
                            '비밀번호 찾기',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

// 기본 로그인 데이터 저장 - 최소한의 작업만 수행
  Future<void> _saveBasicLoginData(Map<String, dynamic> authResponse) async {
    final prefs = await SharedPreferences.getInstance();

    // 토큰 저장 (가장 중요)
    await prefs.setString('access_token', authResponse['accessToken']);
    await prefs.setString('refresh_token', authResponse['refreshToken']);

    // 기본 사용자 정보만 저장
    String userId = "";
    if (authResponse['userProfile'] != null) {
      final userProfile = authResponse['userProfile'];

      if (userProfile['id'] != null) {
        userId = userProfile['id'].toString();
        await prefs.setString('user_id', userId);
      }
      if (userProfile['name'] != null) {
        await prefs.setString('user_name', userProfile['name']);
      }
      if (userProfile['email'] != null) {
        await prefs.setString('user_email', userProfile['email']);
      }

      // 로그인 타입 저장
      if (userProfile['loginType'] != null) {
        await prefs.setInt('login_type', userProfile['loginType']);
      } else {
        await prefs.setInt('login_type', 0);
      }
    }

    // 첫 로그인 상태 간단하게 설정
    final String firstLoginKey = 'user_first_login_$userId';
    final bool hasFirstLoginRecord = prefs.containsKey(firstLoginKey);

    if (hasFirstLoginRecord) {
      final isFirstLogin = prefs.getBool(firstLoginKey) ?? false;
      await prefs.setBool('is_first_login', isFirstLogin);
    } else {
      await prefs.setBool(firstLoginKey, true);
      await prefs.setBool('is_first_login', true);
    }
  }

// 선호도 로드를 백그라운드에서 수행
  void _loadPreferencesInBackground(Map<String, dynamic> authResponse) {
    // 비동기로 실행하되 에러가 발생해도 앱 실행에 영향 주지 않음
    Future.delayed(Duration.zero, () async {
      try {
        if (mounted) {
          final prefProvider = Provider.of<UserPreferenceProvider>(
              context,
              listen: false
          );

          await prefProvider.resetPreferences();

          final prefs = await SharedPreferences.getInstance();
          final userId = prefs.getString('user_id');

          if (userId != null && userId.isNotEmpty) {
            await prefProvider.loadPreferencesForUser(userId);
            print('백그라운드에서 사용자 선호도 로드 완료');
          }
        }
      } catch (e) {
        print('백그라운드 선호도 로드 실패: $e');
        // 실패해도 무시 - 나중에 다시 시도할 수 있음
      }
    });
  }

// 일반 로그인 처리 - 최적화됨
  void _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isEmailLoginLoading = true;  // 일반 로그인 로딩만 활성화
      });

      // 웹 환경과 모바일 환경에 따라 다른 URL 사용
      final apiUrl = kIsWeb
          ? 'http://localhost:8086/api/v1/auth/login'
          : '$baseUrl/auth/login';

      print('사용 중인 API URL: $apiUrl');

      try {
        // 타임아웃 설정 추가 - 매우 중요!
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': _emailController.text,
            'password': _passwordController.text,
          }),
        ).timeout(const Duration(seconds: 10)); // 10초 타임아웃

        print('응답 상태 코드: ${response.statusCode}');

        if (response.statusCode == 200) {
          final authResponse = json.decode(response.body);
          print('파싱된 응답: $authResponse');

          // 기본 데이터만 저장하고 화면 이동
          await _saveBasicLoginData(authResponse);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigation()),
            );
          }

          // 선호도 로드는 백그라운드에서
          _loadPreferencesInBackground(authResponse);

        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('로그인 실패: 상태 코드 ${response.statusCode}')),
            );
          }
        }
      } catch (e) {
        print('로그인 요청 중 오류 발생: $e');
        if (mounted) {
          String errorMessage = '네트워크 오류가 발생했습니다';
          if (e.toString().contains('TimeoutException')) {
            errorMessage = '서버 응답 시간이 초과되었습니다';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isEmailLoginLoading = false;  // 일반 로그인 로딩 비활성화
          });
        }
      }
    }
  }
}