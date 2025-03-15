import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trip_helper/widgets/auth/custom_text_field.dart';
import 'package:trip_helper/widgets/auth/timer_button.dart';

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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _buildUserVerification(),
            if (_isVerified) ...[
              const SizedBox(height: 32),
              _buildNewPasswordFields(),
            ],
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserVerification() {
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
          enabled: !_isVerified,
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
        ),
        if (!_isVerified) ...[
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
                ),
              ),
              const SizedBox(width: 8),
              TimerButton(
                onPressed: _requestVerification,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _verifyUser,
              child: const Text('본인 확인'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNewPasswordFields() {
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
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _handleSubmit,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _isVerified ? '비밀번호 변경' : '다음',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _requestVerification() {
    // TODO: 인증번호 요청 처리
    print('Requesting verification code');
  }

  void _verifyUser() {
    // TODO: 사용자 인증 처리
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isVerified = true;
      });
    }
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_isVerified) {
        _verifyUser();
      } else {
        // TODO: 비밀번호 변경 처리
        print('Resetting password');
        print('New password: ${_newPasswordController.text}');
      }
    }
  }
}