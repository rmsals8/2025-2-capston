// lib/main.dart - 완전한 파일

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'; // 추가
import 'screens/auth/auth_screen.dart';
import 'screens/main_navigation.dart';
import 'providers/schedule_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/route_provider.dart';
import 'providers/location_provider.dart';
import 'providers/navigation_provider.dart';
import 'services/navigation_service.dart';
import 'services/visit_history_service.dart';  // 추가: 방문 기록 서비스
import 'services/place_recommendation_service.dart';  // 추가: 장소 추천 서비스
import 'providers/user_preference_provider.dart';

Future<void> initializeApp() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // 카카오 SDK 초기화 (추가된 부분)
  KakaoSdk.init(
    nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? 'YOUR_NATIVE_APP_KEY',
  );

  // Google Maps 렌더러 초기화
  final GoogleMapsFlutterPlatform mapsImplementation = GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    await (mapsImplementation as GoogleMapsFlutterAndroid).initializeWithRenderer(
        AndroidMapRenderer.latest
    );
  }

  // Firebase 초기화 - 한 번만 실행되도록 수정
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY'] ?? '',
        appId: dotenv.env['FIREBASE_APP_ID'] ?? '',
        messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
        projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
      ),
    );
  }
}

void main() async {
  try {
    await initializeApp();

    // ✅ AuthProvider를 먼저 생성하고 초기화
    final authProvider = AuthProvider();
    await authProvider.initializeAuth(); // 새로운 초기화 메서드 호출

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');

    // ✅ 토큰이 있고 AuthProvider의 로그인 상태가 true인 경우만 로그인 상태로 설정
    final bool isLoggedIn = token != null && authProvider.isLoggedIn;

    print('앱 시작 - 토큰 존재: ${token != null}, AuthProvider 로그인 상태: ${authProvider.isLoggedIn}, 최종 로그인 상태: $isLoggedIn');

    // 서비스 및 Provider 초기화
    final navigationService = NavigationService();
    final locationProvider = LocationProvider();
    final routeProvider = RouteProvider();
    final navigationProvider = NavigationProvider();
    final visitHistoryService = VisitHistoryService();  // 추가: 방문 기록 서비스
    final placeRecommendationService = PlaceRecommendationService();  // 추가: 장소 추천 서비스

    runApp(
      MultiProvider(
        providers: [
          Provider<NavigationService>.value(value: navigationService),
          Provider<VisitHistoryService>.value(value: visitHistoryService),  // 추가
          ChangeNotifierProvider(create: (_) => UserPreferenceProvider()),
          Provider<PlaceRecommendationService>.value(value: placeRecommendationService),  // 추가
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider), // ✅ 초기화된 AuthProvider 사용
          ChangeNotifierProvider<LocationProvider>.value(value: locationProvider),
          ChangeNotifierProvider<RouteProvider>.value(value: routeProvider),
          ChangeNotifierProvider<NavigationProvider>.value(value: navigationProvider),
          ChangeNotifierProxyProvider<AuthProvider, ScheduleProvider>(
            create: (context) => ScheduleProvider(
              authProvider: authProvider, // ✅ 초기화된 AuthProvider 사용
            ),
            update: (context, auth, previous) => ScheduleProvider(
              authProvider: auth,
            ),
          ),
          ChangeNotifierProvider(create: (_) => RouteProvider()),
        ],
        child: MyApp(isLoggedIn: isLoggedIn), // ✅ 정확한 로그인 상태 전달
      ),
    );
  } catch (e) {
    print('Initialization error: $e');
    // 에러가 발생해도 기본 Provider들은 제공
    final authProvider = AuthProvider();
    runApp(
      MultiProvider(
        providers: [
          Provider<NavigationService>(create: (_) => NavigationService()),
          Provider<VisitHistoryService>(create: (_) => VisitHistoryService()),  // 추가
          Provider<PlaceRecommendationService>(create: (_) => PlaceRecommendationService()),  // 추가
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => UserPreferenceProvider()),
          ChangeNotifierProvider<LocationProvider>(create: (_) => LocationProvider()),
          ChangeNotifierProvider<ScheduleProvider>(create: (_) => ScheduleProvider(authProvider: authProvider)),
          ChangeNotifierProvider<RouteProvider>(create: (_) => RouteProvider()),
          ChangeNotifierProvider<NavigationProvider>(
            create: (context) => NavigationProvider(),
          ),
        ],
        child: const MyApp(isLoggedIn: false),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({
    Key? key,
    required this.isLoggedIn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('MyApp 빌드 - 초기 로그인 상태: $isLoggedIn');

    return MaterialApp(
      title: '여행 도우미',
      navigatorKey: NavigationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
      ),
      // ✅ Consumer를 사용해서 AuthProvider 상태 변화를 실시간으로 감지
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          print('Consumer 빌드 - AuthProvider 로그인 상태: ${authProvider.isLoggedIn}');

          // ✅ AuthProvider의 실시간 상태에 따라 화면 결정
          return authProvider.isLoggedIn ? const MainNavigation() : const AuthScreen();
        },
      ),
    );
  }
}