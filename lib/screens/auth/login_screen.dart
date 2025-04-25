// lib/screens/auth/login_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trip_helper/widgets/auth/custom_text_field.dart';
import 'package:trip_helper/screens/main_navigation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_helper/widgets/auth/kakao_image_button.dart';
import '../../widgets/auth/modern_social_login_button.dart';
import '../../widgets/auth/naver_image_button.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  bool _isLoading = false;
  final baseUrl = dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8081/api/v1';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                    const Text(
                      '여행 도우미',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '환영합니다',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
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
                    
                    // 로그인 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
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
                    
                    // 카카오 로그인
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE500),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        onPressed: () {},
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble,
                              color: Colors.black.withOpacity(0.85),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '카카오로 계속하기',
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.85),
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

void _handleLogin() async {
  if (_formKey.currentState?.validate() ?? false) {
    setState(() {
      _isLoading = true;
    });

    // 웹 환경과 모바일 환경에 따라 다른 URL 사용
    final apiUrl = kIsWeb 
        ? 'http://localhost:8081/api/v1/auth/login' 
        : '$baseUrl/auth/login';
    
    print('사용 중인 API URL: $apiUrl');
    print('요청 데이터: ${json.encode({
      'email': _emailController.text,
      'password': _passwordController.text,
    })}');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      print('응답 상태 코드: ${response.statusCode}');
      print('응답 헤더: ${response.headers}');
      print('응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final authResponse = json.decode(response.body);
        print('파싱된 응답: $authResponse');
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', authResponse['accessToken']);
        await prefs.setString('refresh_token', authResponse['refreshToken']);

        // 사용자 정보 저장
        if (authResponse['userProfile'] != null) {
          final userProfile = authResponse['userProfile'];
          
          if (userProfile['id'] != null) {
            await prefs.setString('user_id', userProfile['id'].toString());
          }
          
          if (userProfile['name'] != null) {
            await prefs.setString('user_name', userProfile['name']);
          }
          
          if (userProfile['email'] != null) {
            await prefs.setString('user_email', userProfile['email']);
          }
          
          // 로그인 타입 저장 추가
          if (userProfile['loginType'] != null) {
            await prefs.setInt('login_type', userProfile['loginType']);
          } else {
            // 일반 로그인 시 loginType이 없으면 0으로 설정
            await prefs.setInt('login_type', 0);
          }
          
          // 첫 로그인 상태 설정 (핵심 변경 부분)
          // 서버에서 isFirstLogin 정보를 제공하는 경우
          if (userProfile['isFirstLogin'] != null) {
            await prefs.setBool('is_first_login', userProfile['isFirstLogin']);
            print('서버에서 받은 첫 로그인 상태: ${userProfile['isFirstLogin']}');
          } else {
            // 서버에서 해당 정보를 제공하지 않는 경우, 가입일자 기반으로 판단하거나 기본값 설정
            // 테스트를 위해 일단 true로 설정
            await prefs.setBool('is_first_login', true);
            print('첫 로그인 상태를 true로 설정 (테스트용)');
          }
        } else {
          // userProfile이 없는 경우 기본값 설정
          await prefs.setInt('login_type', 0);
          // 첫 로그인 상태도 설정 (추가된 부분)
          await prefs.setBool('is_first_login', true);
          print('userProfile이 없어 첫 로그인 상태를 true로 설정');
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigation()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('로그인 실패: 상태 코드 ${response.statusCode}, 메시지: ${response.body}')),
          );
        }
      }
    } catch (e) {
      print('로그인 요청 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('네트워크 오류: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
}