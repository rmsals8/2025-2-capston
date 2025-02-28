import 'package:flutter/material.dart';
import 'package:trip_helper/screens/auth/login_screen.dart';
import 'package:trip_helper/screens/auth/register_screen.dart';
import 'package:trip_helper/screens/auth/password_reset_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // SingleTickerProviderStateMixin 제거됨 - TabController가 없으므로 필요 없음

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LoginScreen(
          onRegisterTap: () {
            // 회원가입 화면으로 이동할 때 Scaffold가 있는 화면으로 이동
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    title: const Text('회원가입'),
                    elevation: 0,
                  ),
                  body: const RegisterScreen(),
                ),
              ),
            );
          },
          onPasswordResetTap: () {
            // 비밀번호 찾기 화면으로 이동할 때 Scaffold가 있는 화면으로 이동
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    title: const Text('비밀번호 찾기'),
                    elevation: 0,
                  ),
                  body: const PasswordResetScreen(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}