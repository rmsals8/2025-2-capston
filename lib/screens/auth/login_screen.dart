import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trip_helper/widgets/auth/custom_text_field.dart';
import 'package:trip_helper/widgets/auth/social_login_button.dart';
import 'package:trip_helper/screens/main_navigation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _autoLogin = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _buildEmailField(),
            const SizedBox(height: 16),
            _buildPasswordField(),
            const SizedBox(height: 8),
            _buildAutoLoginCheckbox(),
            const SizedBox(height: 24),
            _buildLoginButton(),
            const SizedBox(height: 16),
            _buildDivider(),
            const SizedBox(height: 16),
            _buildSocialLoginButtons(),
            const SizedBox(height: 24),
            _buildBottomLinks(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return CustomTextField(
      controller: _emailController,
      hint: '이메일',
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '이메일을 입력해주세요';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return '올바른 이메일 형식이 아닙니다';
        }
        return null;
      },
      prefix: const Icon(Icons.email_outlined),
    );
  }

  Widget _buildPasswordField() {
    return CustomTextField(
      controller: _passwordController,
      hint: '비밀번호',
      obscureText: true,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '비밀번호를 입력해주세요';
        }
        if (value.length < 6) {
          return '비밀번호는 6자 이상이어야 합니다';
        }
        return null;
      },
      prefix: const Icon(Icons.lock_outline),
    );
  }

  Widget _buildAutoLoginCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _autoLogin,
          onChanged: (value) {
            setState(() {
              _autoLogin = value ?? false;
            });
          },
        ),
        const Text('자동 로그인'),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _handleLogin,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '로그인',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: const [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('또는'),
        ),
        Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildSocialLoginButtons() {
    return Column(
      children: [
        SocialLoginButton(
          type: SocialLoginType.kakao,
          onLoginSuccess: (code) {
            print('Kakao Login Success with code: $code');
          },
          onLoginError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          },
        ),
        const SizedBox(height: 12),
        SocialLoginButton(
          type: SocialLoginType.naver,
          onLoginSuccess: (code) {
            print('Naver Login Success with code: $code');
          },
          onLoginError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () {
            // TODO: 회원가입 페이지로 이동
          },
          child: const Text('회원가입'),
        ),
        Container(
          width: 1,
          height: 12,
          color: Colors.grey[300],
          margin: const EdgeInsets.symmetric(horizontal: 8),
        ),
        TextButton(
          onPressed: () {
            // TODO: 비밀번호 찾기 페이지로 이동
          },
          child: const Text('비밀번호 찾기'),
        ),
      ],
    );
  }

  void _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        // 로그인 요청
        final response = await http.post(
          Uri.parse('http://10.0.2.2:8080/api/v1/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': _emailController.text,
            'password': _passwordController.text,
          }),
        );

        if (response.statusCode == 200) {
          // 응답 파싱
          final authResponse = json.decode(response.body);

          // 토큰 저장 - Bearer 접두사 추가
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', authResponse['accessToken']);
          await prefs.setString('refresh_token', authResponse['refreshToken']);

          // 토큰이 저장되었는지 확인하기 위한 디버그 출력
          print('Tokens saved - Access Token: ${authResponse['accessToken']}');

          // 자동 로그인 설정 저장
          await prefs.setBool('auto_login', _autoLogin);

          // 메인 화면으로 이동
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigation()),
            );
          }
        } else {
          if (mounted) {
            // 로그인 실패 처리
            final errorResponse = json.decode(response.body);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorResponse['message'] ?? '로그인 실패')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          // 네트워크 오류 등 예외 처리
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('로그인 중 오류가 발생했습니다: $e')),
          );
        }
      }
    }
  }
}