import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_helper/widgets/auth/custom_text_field.dart';
import 'package:http/http.dart' as http;
import 'package:trip_helper/screens/main_navigation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // 현재 단계 (0: 이메일 입력, 1: 인증코드 입력, 2: 회원정보 입력)
  int _currentStep = 0;

  // 컨트롤러
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // API URL
  // final baseUrl = 'http://localhost:8086/api/v1';
  final baseUrl = dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8086/api/v1';
  // 로딩 상태
  bool _isLoading = false;

  // 인증 토큰
  String? _verificationToken;

  // 약관 동의
  bool _agreeToTerms = false;
  bool _agreeToMarketing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentStep == 0)
                    _buildEmailStep(),
                  if (_currentStep == 1)
                    _buildVerificationStep(),
                  if (_currentStep == 2)
                    _buildSignupStep(),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 단계 1: 이메일 입력
  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Text(
          '이메일 인증',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '회원가입을 위해 이메일 인증이 필요합니다.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 48),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomTextField(
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
            prefix: const Icon(Icons.email_outlined, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _requestEmailVerification,
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
                    '인증 코드 요청',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // 단계 2: 인증코드 입력
  Widget _buildVerificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Text(
          '인증 코드 확인',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_emailController.text}로 전송된 6자리 인증 코드를 입력해주세요.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '인증 코드는 5분간 유효합니다.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 48),
        // 이메일 표시 (비활성화)
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomTextField(
            controller: _emailController,
            hint: '이메일',
            enabled: false,
            prefix: const Icon(Icons.email_outlined, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 16),
        // 인증코드 입력
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomTextField(
            controller: _codeController,
            hint: '인증 코드 6자리',
            keyboardType: TextInputType.number,
            prefix: const Icon(Icons.security, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _isLoading ? null : _requestEmailVerification,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: const Text('인증번호 재발송'),
            ),
            TextButton(
              onPressed: _isLoading ? null : () {
                setState(() {
                  _currentStep = 0;
                  _codeController.clear();
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: const Text('이메일 변경'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyCode,
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
                    '확인',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // 단계 3: 회원정보 입력
  Widget _buildSignupStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Text(
          '회원정보 입력',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '인증이 완료되었습니다. 회원가입을 완료해주세요.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 48),
        // 인증된 이메일 (읽기 전용)
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomTextField(
            controller: _emailController,
            hint: '이메일',
            enabled: false,
            prefix: const Icon(Icons.email_outlined, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 16),
        // 이름
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomTextField(
            controller: _nameController,
            hint: '이름',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '이름을 입력해주세요';
              }
              return null;
            },
            prefix: const Icon(Icons.person_outline, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 16),
        // 비밀번호
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomTextField(
            controller: _passwordController,
            hint: '비밀번호',
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '비밀번호를 입력해주세요';
              }
              if (value.length < 8) {
                return '비밀번호는 8자 이상이어야 합니다';
              }
              return null;
            },
            prefix: const Icon(Icons.lock_outline, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 16),
        // 비밀번호 확인
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomTextField(
            controller: _confirmPasswordController,
            hint: '비밀번호 확인',
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '비밀번호를 다시 입력해주세요';
              }
              if (value != _passwordController.text) {
                return '비밀번호가 일치하지 않습니다';
              }
              return null;
            },
            prefix: const Icon(Icons.lock_outline, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 24),
        // 약관 동의
        CheckboxListTile(
          title: const Text(
            '서비스 이용약관 동의 (필수)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),
          value: _agreeToTerms,
          onChanged: (value) {
            setState(() {
              _agreeToTerms = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: Colors.black,
          checkboxShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        CheckboxListTile(
          title: const Text(
            '마케팅 정보 수신 동의 (선택)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),
          value: _agreeToMarketing,
          onChanged: (value) {
            setState(() {
              _agreeToMarketing = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: Colors.black,
          checkboxShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 24),
        // 회원가입 버튼
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleCompleteSignup,
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
                    '회원가입',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // 이메일 인증 요청
  Future<void> _requestEmailVerification() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일을 입력해주세요')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/email-verify-request'),
        body: json.encode({
          'email': _emailController.text,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      print('이메일 인증 요청 응답 상태 코드: ${response.statusCode}');
      print('이메일 인증 요청 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        // 다음 단계로 이동
        setState(() {
          _currentStep = 1;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증 코드가 발송되었습니다. 이메일을 확인해주세요.')),
        );
      } else {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('인증 코드 발송에 실패했습니다: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  // 인증 코드 확인
  Future<void> _verifyCode() async {
    if (_codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증 코드를 입력해주세요')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-email'),
        body: json.encode({
          'email': _emailController.text,
          'verificationCode': _codeController.text,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      print('인증 코드 확인 응답 상태 코드: ${response.statusCode}');
      print('인증 코드 확인 응답 내용: ${response.body}');

      final data = json.decode(response.body);

      // HTTP 상태 코드가 200이고 data['status']가 200인 경우만 성공으로 판단
      if (response.statusCode == 200 && data['status'] == 200) {
        _verificationToken = data['data']['resetToken'];

        setState(() {
          _currentStep = 2;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증이 완료되었습니다. 회원정보를 입력해주세요.')),
        );
      } else {
        setState(() {
          _isLoading = false;
        });

        // 서버에서 반환한 오류 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? '인증번호가 올바르지 않습니다.')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }
  
  // 회원가입 완료
  // 회원가입 완료
Future<void> _handleCompleteSignup() async {
  if (_nameController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이름을 입력해주세요')),
    );
    return;
  }

  if (_passwordController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('비밀번호를 입력해주세요')),
    );
    return;
  }

  if (_passwordController.text.length < 8) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('비밀번호는 8자 이상이어야 합니다')),
    );
    return;
  }

  if (_passwordController.text != _confirmPasswordController.text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('비밀번호가 일치하지 않습니다')),
    );
    return;
  }

  if (!_agreeToTerms) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('서비스 이용약관에 동의해주세요')),
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/complete-signup'),
      body: json.encode({
        'email': _emailController.text,
        'password': _passwordController.text,
        'name': _nameController.text,
        'verificationToken': _verificationToken,
        'termsAgreed': _agreeToTerms,
        'marketingAgreed': _agreeToMarketing
      }),
      headers: {'Content-Type': 'application/json'},
    );

    print('회원가입 완료 응답 상태 코드: ${response.statusCode}');
    print('회원가입 완료 응답 내용: ${response.body}');

    if (response.statusCode == 200) {
      final authResponse = json.decode(response.body);

      // 사용자 정보 및 토큰 저장
      final prefs = await SharedPreferences.getInstance();

      if (authResponse['accessToken'] != null) {
        await prefs.setString('access_token', authResponse['accessToken']);
      }
      if (authResponse['refreshToken'] != null) {
        await prefs.setString('refresh_token', authResponse['refreshToken']);
      }

      String userId = "";
      if (authResponse['userProfile'] != null) {
        final userProfile = authResponse['userProfile'];

        if (userProfile['id'] != null) {
          userId = userProfile['id'].toString();
          await prefs.setString('user_id', userId);
        }

        if (userProfile['name'] != null) {
          await prefs.setString('user_name', userProfile['name']);
        } else {
          await prefs.setString('user_name', _nameController.text);
        }

        if (userProfile['email'] != null) {
          await prefs.setString('user_email', userProfile['email']);
        } else {
          await prefs.setString('user_email', _emailController.text);
        }
      }

      // 첫 로그인 상태를 명시적으로 true로 설정 (핵심 수정 부분)
      await prefs.setBool('is_first_login', true);
      print('회원가입 완료: 첫 로그인 상태를 true로 설정');
      
      // 사용자별 첫 로그인 상태도 함께 설정
      if (userId.isNotEmpty) {
        final userFirstLoginKey = 'user_first_login_$userId';
        await prefs.setBool(userFirstLoginKey, true);
        print('회원가입 완료: 사용자 $userId의 첫 로그인 상태를 true로 설정');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입에 성공했습니다!')),
      );

      // 메인 화면으로 이동
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
      });

      final errorResponse = json.decode(response.body);
      String errorMessage = '회원가입에 실패했습니다';

      if (errorResponse['message'] != null) {
        errorMessage = errorResponse['message'];
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  } catch (e) {
    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('회원가입 처리 중 오류가 발생했습니다: $e')),
    );
  }
}
}