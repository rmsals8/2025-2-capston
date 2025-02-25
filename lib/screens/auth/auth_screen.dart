import 'package:flutter/material.dart';
import 'package:trip_helper/screens/auth/login_screen.dart';
import 'package:trip_helper/screens/auth/register_screen.dart';
import 'package:trip_helper/screens/auth/password_reset_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: '로그인'),
                Tab(text: '회원가입'),
                Tab(text: '비밀번호 찾기'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  LoginScreen(),
                  RegisterScreen(),
                  PasswordResetScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}