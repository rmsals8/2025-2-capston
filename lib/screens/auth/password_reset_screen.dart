import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trip_helper/widgets/auth/custom_text_field.dart';
import 'package:trip_helper/widgets/auth/timer_button.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_helper/screens/main_navigation.dart';

import 'auth_screen.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({Key? key}) : super(key: key);

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _verificationController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isVerified = false;
  String _resetToken = '';
  bool _isLoading = false;
  bool _showPasswordScreen = false;

  final baseUrl = dotenv.env['API_V1_URL'] ?? 'https://port-0-capston-m89fv9wece79f0ad.sel4.cloudtype.app/api/v1';

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _verificationController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("빌드 - 인증 상태: $_isVerified, 비밀번호 화면 표시: $_showPasswordScreen");

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _showPasswordScreen ? _buildPasswordForm() : _buildVerificationForm(),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  // 인증 화면
  Widget _buildVerificationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '본인 확인',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _phoneController,
          hint: '전화번호',
          keyboardType: TextInputType.phone,
          // 인증 완료 시 비활성화
          enabled: !_isVerified,
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
          prefix: const Icon(Icons.phone_android),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _emailController,
          hint: '이메일',
          keyboardType: TextInputType.emailAddress,
          // 인증 완료 시 비활성화
          enabled: !_isVerified,
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
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _verificationController,
                hint: '인증번호',
                keyboardType: TextInputType.number,
                enabled: !_isVerified,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '인증번호를 입력해주세요';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            // TimerButton의 onPressed는 null을 허용하지 않으므로 조건부 함수 사용
            TimerButton(
              onPressed: _isVerified
                  ? () {} // 비활성화 상태에서는 빈 함수 전달
                  : _requestVerification,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 본인 확인 버튼 - 인증 완료 시 비활성화
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: !_isVerified ? _verifyUser : null,
            style: ElevatedButton.styleFrom(
              // 인증 완료 시 회색으로 변경
              backgroundColor: !_isVerified ? null : Colors.grey[300],
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '본인 확인',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                // 인증 완료 시 텍스트 색상 변경
                color: !_isVerified ? null : Colors.grey[600],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 다음 버튼 - 인증 성공 시 활성화
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isVerified
                ? () {
              print("다음 버튼 클릭됨, 인증 상태: $_isVerified");
              _goToPasswordScreen();
            }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isVerified ? null : Colors.grey[300],
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '다음',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _isVerified ? null : Colors.grey[600],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 비밀번호 변경 화면
  Widget _buildPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '새 비밀번호 설정',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _newPasswordController,
          hint: '새 비밀번호',
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '새 비밀번호를 입력해주세요';
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
          hint: '새 비밀번호 확인',
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '비밀번호를 다시 입력해주세요';
            }
            if (value != _newPasswordController.text) {
              return '비밀번호가 일치하지 않습니다';
            }
            return null;
          },
          prefix: const Icon(Icons.lock_outline),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            // 여기서 메인 화면으로 바로 이동 버튼
            // password_reset_screen.dart의 비밀번호 변경 버튼 부분
// 이 코드로 기존 비밀번호 변경 버튼 onPressed 부분을 교체하세요

            onPressed: () async {
              // 유효성 검사 통과 시
              if (_formKey.currentState?.validate() ?? false) {
                // 로딩 표시
                setState(() {
                  _isLoading = true;
                });

                try {
                  // 비밀번호 변경 요청
                  final requestBody = {
                    'email': _emailController.text,
                    'resetToken': _resetToken,
                    'newPassword': _newPasswordController.text,
                  };

                  final response = await http.post(
                    Uri.parse('$baseUrl/auth/password/update'),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode(requestBody),
                  );

                  print('비밀번호 변경 응답: ${response.statusCode}, ${response.body}');

                  setState(() {
                    _isLoading = false;
                  });

                  final responseData = json.decode(response.body);
                  bool isSuccess = false;

                  if (response.statusCode == 200) {
                    isSuccess = true;
                  } else if (responseData['status'] == 'success') {
                    isSuccess = true;
                  } else if (responseData['success'] == true) {
                    isSuccess = true;
                  }

                  if (isSuccess) {
                    // 성공 메시지
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('비밀번호가 성공적으로 변경되었습니다. 다시 로그인해주세요.'),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // 핵심: 모든 인증 데이터 명시적으로 삭제
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('access_token');
                    await prefs.remove('refresh_token');
                    await prefs.remove('user_name');
                    await prefs.remove('user_email');
                    await prefs.remove('user_id');
                    await prefs.remove('auto_login');

                    // 로그 추가
                    print('모든 인증 데이터 삭제 완료');

                    // 지연 후 로그인 화면으로 이동 (인증 화면의 시작점으로)
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) {
                        // 모든 화면을 제거하고 인증 화면으로 이동
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const AuthScreen()),
                              (route) => false,
                        );
                      }
                    });
                  } else {
                    // 실패 메시지
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(responseData['message'] ?? '비밀번호 변경 실패')),
                    );
                  }
                } catch (e) {
                  setState(() {
                    _isLoading = false;
                  });

                  print('비밀번호 변경 오류: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('오류 발생: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '비밀번호 변경',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 디버깅용 버튼 추가 - 비밀번호 변경 시도 없이 바로 메인 화면으로 이동
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              // 바로 메인 화면으로 이동
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MainNavigation()),
                    (route) => false,
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('테스트: 바로 메인 화면으로'),
          ),
        ),
      ],
    );
  }

  // 비밀번호 화면으로 전환
  void _goToPasswordScreen() {
    print("비밀번호 화면으로 전환");
    setState(() {
      _showPasswordScreen = true;
    });
  }

  // 인증번호 요청
  void _requestVerification() async {
    if (_emailController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 전화번호를 입력해주세요')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final requestBody = {
        'email': _emailController.text,
        'phoneNumber': _phoneController.text,
      };
      print('인증번호 요청 본문: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/password/reset-request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('인증번호 요청 응답 상태 코드: ${response.statusCode}');
      print('인증번호 요청 응답 본문: ${response.body}');

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? '인증번호가 발송되었습니다')),
        );
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorData['message'] ?? '인증번호 요청 실패')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('인증번호 요청 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    }
  }

  // 인증번호 확인
  void _verifyUser() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        final requestBody = {
          'email': _emailController.text,
          'verificationCode': _verificationController.text,
        };
        print('인증번호 확인 요청 본문: $requestBody');

        final response = await http.post(
          Uri.parse('$baseUrl/auth/password/verify-code'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        );

        print('인증번호 확인 응답 상태 코드: ${response.statusCode}');
        print('인증번호 확인 응답 본문: ${response.body}');

        // 디버깅을 위해 전체 응답 출력
        print('전체 응답: ${response.body}');

        final responseData = json.decode(response.body);

        // 인증 성공 여부를 더 명확하게 확인
        bool isSuccess = false;

        // 다양한 성공 패턴 확인
        if (response.statusCode == 200) {
          isSuccess = true;
        } else if (responseData['status'] == 'success') {
          isSuccess = true;
        } else if (responseData['success'] == true) {
          isSuccess = true;
        }

        // 토큰 저장
        String resetToken = '';
        if (responseData['data'] != null && responseData['data']['resetToken'] != null) {
          resetToken = responseData['data']['resetToken'];
        } else if (responseData['resetToken'] != null) {
          resetToken = responseData['resetToken'];
        }

        // 디버깅 정보 출력
        print("응답 데이터: $responseData");
        print("인증 성공 여부: $isSuccess");
        print("리셋 토큰: $resetToken");

        setState(() {
          _isLoading = false;
          _isVerified = isSuccess;
          _resetToken = resetToken;
        });

        // UI 업데이트를 위한 두 번째 setState 호출 (강제 리렌더링)
        if (isSuccess) {
          setState(() {}); // 강제 리렌더링

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('인증되었습니다. 다음 버튼을 눌러 비밀번호를 변경해주세요')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] ?? '인증 실패')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        print('인증번호 확인 오류: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('네트워크 오류: $e')),
        );
      }
    }
  }
}
