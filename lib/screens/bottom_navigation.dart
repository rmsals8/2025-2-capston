import 'package:flutter/material.dart';
import 'package:trip_helper/screens/home/home_screen.dart';
import 'package:trip_helper/screens/route/route_generation_screen.dart';
import 'package:trip_helper/screens/profile/profile_history_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_helper/screens/navigation/navigation_screen.dart';
class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // 기본 좌표값 설정 (예: 서울시청)
  final LatLng defaultLocation = const LatLng(37.5665, 126.9780);

  // 페이지 리스트를 getter로 변경하여 동적으로 생성
  List<Widget> get _pages => [
    const HomeScreen(),
    const RouteGenerationScreen(),
    NavigationScreen(  // 수정된 부분
      startLocation: defaultLocation,
      endLocation: const LatLng(37.5665, 126.9780), // 예시 도착지
    ),
    const ProfileHistoryScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '경로',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.navigation),
            label: '내비게이션',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '프로필',
          ),
        ],
      ),
    );
  }
}