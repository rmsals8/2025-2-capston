// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
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

Future<void> initializeApp() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

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

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');

    // 서비스 및 Provider 초기화
    final navigationService = NavigationService();
    final authProvider = AuthProvider();
    final locationProvider = LocationProvider();
    final scheduleProvider = ScheduleProvider();
    final routeProvider = RouteProvider();
    final navigationProvider = NavigationProvider();
    final visitHistoryService = VisitHistoryService();  // 추가: 방문 기록 서비스
    final placeRecommendationService = PlaceRecommendationService();  // 추가: 장소 추천 서비스

    runApp(
      MultiProvider(
        providers: [
          Provider<NavigationService>.value(value: navigationService),
          Provider<VisitHistoryService>.value(value: visitHistoryService),  // 추가
          Provider<PlaceRecommendationService>.value(value: placeRecommendationService),  // 추가
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<LocationProvider>.value(value: locationProvider),
          ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
          ChangeNotifierProvider<RouteProvider>.value(value: routeProvider),
          ChangeNotifierProvider<NavigationProvider>.value(value: navigationProvider),
        ],
        child: MyApp(isLoggedIn: token != null),
      ),
    );
  } catch (e) {
    print('Initialization error: $e');
    // 에러가 발생해도 기본 Provider들은 제공
    runApp(
      MultiProvider(
        providers: [
          Provider<NavigationService>(create: (_) => NavigationService()),
          Provider<VisitHistoryService>(create: (_) => VisitHistoryService()),  // 추가
          Provider<PlaceRecommendationService>(create: (_) => PlaceRecommendationService()),  // 추가
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<LocationProvider>(create: (_) => LocationProvider()),
          ChangeNotifierProvider<ScheduleProvider>(create: (_) => ScheduleProvider()),
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
    return MaterialApp(
      title: '여행 도우미',
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
      home: isLoggedIn ? const MainNavigation() : const AuthScreen(),
    );
  }
}
