// lib/screens/main_navigation.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_helper/providers/user_preference_provider.dart';
import 'package:trip_helper/screens/home/home_screen.dart';
import 'package:trip_helper/screens/route/route_generation_screen.dart';
import 'package:trip_helper/screens/profile/profile_history_screen.dart';
import 'package:trip_helper/providers/location_provider.dart';
import 'package:trip_helper/providers/navigation_provider.dart';
import 'package:trip_helper/services/navigation_service.dart';
import 'package:trip_helper/services/visit_history_service.dart';
import 'package:trip_helper/services/place_recommendation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/category_preference_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  
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
      
      // 첫 로그인 체크 및 카테고리 선호도 화면으로 이동
      _checkFirstLogin();
    });
  }
  
  // lib/screens/main_navigation.dart의 _checkFirstLogin 메서드 수정

Future<void> _checkFirstLogin() async {
  // 약간의 지연을 주어 화면 전환이 자연스럽게 하기
  await Future.delayed(const Duration(milliseconds: 100));
  
  if (!mounted) return;
  
  // SharedPreferences에서 직접 확인
  final prefs = await SharedPreferences.getInstance();
  
  // 현재 사용자 ID 가져오기
  final userId = prefs.getString('user_id');
  
  if (userId == null || userId.isEmpty) {
    print('사용자 ID를 찾을 수 없음. 첫 로그인 검사를 건너뜁니다.');
    return;
  }
  
  // 사용자별 첫 로그인 상태 키 생성
  final String userFirstLoginKey = 'user_first_login_$userId';
      
  // 사용자별 첫 로그인 상태 확인
  bool isFirstLogin = false;
  
  // 사용자별 설정이 있으면 그것을 사용
  if (prefs.containsKey(userFirstLoginKey)) {
    isFirstLogin = prefs.getBool(userFirstLoginKey) ?? false;
    print('사용자 $userId의 첫 로그인 상태: $isFirstLogin (사용자별 설정)');
  } else {
    // 없으면 일반 설정 사용
    isFirstLogin = prefs.getBool('is_first_login') ?? false;
    
    // 사용자별 설정도 함께 저장 (동기화)
    if (userId.isNotEmpty) {
      await prefs.setBool(userFirstLoginKey, isFirstLogin);
      print('사용자 $userId의 첫 로그인 상태 생성: $isFirstLogin');
    }
    
    print('일반 첫 로그인 상태: $isFirstLogin');
  }
  
  // is_first_login에도 현재 상태 저장 (다른 화면과의 호환성 유지)
  await prefs.setBool('is_first_login', isFirstLogin);
  
  // 사용자 기반 선호도 확인
  final bool hasPreferredCategories = await _hasUserPreferences(userId);
  
  // 첫 로그인이거나 선호 카테고리가 없는 경우 카테고리 선택 화면으로 이동
  if ((isFirstLogin || !hasPreferredCategories) && mounted) {
    print('첫 로그인 또는 카테고리 선호도 없음: 카테고리 선호도 화면으로 이동합니다.');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CategoryPreferenceScreen(isFirstLogin: true),
      ),
    );
  } else {
    print('첫 로그인 아님: 일반 메인 화면을 표시합니다.');
  }
}

// 사용자별 선호 카테고리 존재 여부 확인
Future<bool> _hasUserPreferences(String userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String userCategoryPrefsKey = 'user_category_preferences_$userId';
    
    // 사용자별 선호 카테고리 가져오기
    final userCategories = prefs.getStringList(userCategoryPrefsKey);
    
    // 선호 카테고리가 있으면 true 반환
    return userCategories != null && userCategories.isNotEmpty;
  } catch (e) {
    print('선호 카테고리 확인 오류: $e');
    return false;
  }
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
        // UserPreferenceProvider 추가
      ChangeNotifierProvider<UserPreferenceProvider>(
        create: (_) => UserPreferenceProvider(),
      ),
      ],
      child: Scaffold(
        backgroundColor: Colors.white,
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const HomeScreen(),
            const RouteGenerationScreen(),
            const ProfileHistoryScreen(),
          ],
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                        label: '홈',
                        index: 0,
                      ),
                      _buildNavItem(
                        icon: Icons.route_outlined,
                        activeIcon: Icons.route,
                        label: '경로',
                        index: 1,
                      ),
                      _buildNavItem(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        label: '프로필',
                        index: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
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