import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_helper/widgets/auth/custom_text_field.dart';
import 'package:trip_helper/widgets/auth/timer_button.dart';
import 'package:http/http.dart' as http;
import 'package:trip_helper/screens/main_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' ;
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _verificationController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  final baseUrl = dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8080/api/v1';
  bool _isPhoneVerified = false;
  bool _agreeToTerms = false;
  bool _agreeToMarketing = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _verificationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
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
            _buildPhoneVerification(),
            const SizedBox(height: 24),
            _buildEmailField(),
            const SizedBox(height: 16),
            _buildNameField(),
            const SizedBox(height: 16),
            _buildPasswordFields(),
            const SizedBox(height: 24),
            _buildAgreements(),
            const SizedBox(height: 32),
            _buildRegisterButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return CustomTextField(
      controller: _nameController,
      hint: '이름',
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '이름을 입력해주세요';
        }
        return null;
      },
      prefix: const Icon(Icons.person_outline),
    );
  }

  Widget _buildPhoneVerification() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _phoneController,
                hint: '전화번호',
                keyboardType: TextInputType.phone,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '전화번호를 입력해주세요';
                  }
                  if (value.length < 10) {
                    return '올바른 전화번호를 입력해주세요';
                  }
                  return null;
                },
                enabled: !_isPhoneVerified,
                prefix: const Icon(Icons.phone_android),
              ),
            ),
            const SizedBox(width: 8),
            TimerButton(
              onPressed: _requestVerification,
            ),
          ],
        ),
        if (!_isPhoneVerified) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _verificationController,
                  hint: '인증번호',
                  keyboardType: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '인증번호를 입력해주세요';
                    }
                    if (value.length != 6) {
                      return '6자리 인증번호를 입력해주세요';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _verifyCode,
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        ],
      ],
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

  Widget _buildPasswordFields() {
    return Column(
      children: [
        CustomTextField(
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
          prefix: const Icon(Icons.lock_outline),
        ),
        const SizedBox(height: 16),
        CustomTextField(
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
          prefix: const Icon(Icons.lock_outline),
        ),
      ],
    );
  }

  Widget _buildAgreements() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('서비스 이용약관 동의 (필수)'),
          value: _agreeToTerms,
          onChanged: (value) {
            setState(() {
              _agreeToTerms = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('마케팅 정보 수신 동의 (선택)'),
          value: _agreeToMarketing,
          onChanged: (value) {
            setState(() {
              _agreeToMarketing = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _handleRegister,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '회원가입',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String? _verificationId;  // 추가

  Future<void> _requestVerification() async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+82${_phoneController.text}',
        verificationCompleted: (PhoneAuthCredential credential) {
          setState(() => _isPhoneVerified = true);
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('인증 실패: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _verificationId = verificationId);  // 저장
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('에러: $e')),
      );
    }
  }

  void _verifyCode() async {
    if (_verificationId == null) return;
    try {
      await FirebaseAuth.instance.signInWithCredential(
          PhoneAuthProvider.credential(
            verificationId: _verificationId!,
            smsCode: _verificationController.text,
          )
      );
      setState(() => _isPhoneVerified = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('인증 실패: $e')),
      );
    }
  }

  void _handleRegister() async {
    if (!_isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화번호 인증을 완료해주세요')),
      );
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서비스 이용약관에 동의해주세요')),
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/auth/signup'),  // 서버 URL 수정
          body: json.encode({
            'email': _emailController.text,
            'password': _passwordController.text,
            'name': _nameController.text,
            'phoneNumber': _phoneController.text,
            'termsAgreed': _agreeToTerms,
            'marketingAgreed': _agreeToMarketing
          }),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final authResponse = json.decode(response.body);

          // 사용자 정보 및 토큰 저장
          final prefs = await SharedPreferences.getInstance();

          // 토큰 저장
          if (authResponse['accessToken'] != null) {
            await prefs.setString('access_token', authResponse['accessToken']);
          }
          if (authResponse['refreshToken'] != null) {
            await prefs.setString('refresh_token', authResponse['refreshToken']);
          }

          // 사용자 정보 저장
          // 사용자 ID 저장
          if (authResponse['userId'] != null) {
            await prefs.setString('user_id', authResponse['userId'].toString());
          } else if (authResponse['user'] != null && authResponse['user']['id'] != null) {
            await prefs.setString('user_id', authResponse['user']['id'].toString());
          }

          // 사용자 이름 저장 - 입력한 이름 사용
          await prefs.setString('user_name', _nameController.text);

          // 사용자 이메일 저장 - 입력한 이메일 사용
          await prefs.setString('user_email', _emailController.text);

          // 디버그 로그
          print('회원가입 성공! 저장된 사용자 정보:');
          print('- 이름: ${prefs.getString('user_name')}');
          print('- 이메일: ${prefs.getString('user_email')}');
          print('- ID: ${prefs.getString('user_id')}');

          // 메인 화면으로 이동
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigation()),
            );
          }
        } else {
          throw Exception('회원가입 실패');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 실패: $e')),
        );
      }
    }
  }
}