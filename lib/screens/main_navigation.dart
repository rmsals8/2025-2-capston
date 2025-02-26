// lib/screens/main_navigation.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_helper/screens/home/home_screen.dart';
import 'package:trip_helper/screens/route/route_generation_screen.dart';
import 'package:trip_helper/screens/profile/profile_history_screen.dart';
import 'package:trip_helper/screens/navigation/navigation_screen.dart';
import 'package:trip_helper/providers/location_provider.dart';
import 'package:trip_helper/providers/navigation_provider.dart';
import 'package:trip_helper/providers/auth_provider.dart';
import 'package:trip_helper/services/navigation_service.dart';
import 'package:trip_helper/services/visit_history_service.dart';
import 'package:trip_helper/services/place_recommendation_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  // 기본 위치 (앱 초기화 시 사용)
  static const LatLng defaultLocation = LatLng(37.5665, 126.9780); // 서울시청

  // 서비스 인스턴스
  final NavigationService _navigationService = NavigationService();
  final VisitHistoryService _visitHistoryService = VisitHistoryService();
  final PlaceRecommendationService _recommendationService = PlaceRecommendationService();

  @override
  void initState() {
    super.initState();

    // 위치 서비스 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      locationProvider.startTracking();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider(),
        ),
        Provider<NavigationService>.value(value: _navigationService),
        Provider<VisitHistoryService>.value(value: _visitHistoryService),
        Provider<PlaceRecommendationService>.value(value: _recommendationService),
      ],
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const HomeScreen(),
            const RouteGenerationScreen(),
            Consumer<LocationProvider>(
              builder: (context, locationProvider, child) {
                return NavigationScreen(
                  startLocation: locationProvider.currentLocation ?? defaultLocation,
                  endLocation: defaultLocation, // 실제로는 사용자의 목적지로 설정 필요
                  transportMode: 'DRIVING', // 기본값
                );
              },
            ),
            const ProfileHistoryScreen(),
          ],
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
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
      ),
    );
  }

  void _onItemTapped(int index) {
    // PageView 컨트롤러를 사용해 페이지 전환
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}