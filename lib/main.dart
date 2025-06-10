// lib/main.dart - 수정된 버전

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 추가: SystemChrome 사용을 위해
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/main_navigation.dart';
import 'providers/schedule_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/route_provider.dart';
import 'providers/location_provider.dart';
import 'providers/navigation_provider.dart';
import 'services/navigation_service.dart';
import 'services/visit_history_service.dart';
import 'services/place_recommendation_service.dart';
import 'providers/user_preference_provider.dart';

Future<void> initializeApp() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 🔒 화면 회전 방지 - 세로 모드로만 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: ".env");

  // 카카오 SDK 초기화
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

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');

    // 서비스 및 Provider 초기화
    final navigationService = NavigationService();
    final authProvider = AuthProvider();
    final locationProvider = LocationProvider();
    final routeProvider = RouteProvider();
    final navigationProvider = NavigationProvider();
    final visitHistoryService = VisitHistoryService();
    final placeRecommendationService = PlaceRecommendationService();

    runApp(
      MultiProvider(
        providers: [
          Provider<NavigationService>.value(value: navigationService),
          Provider<VisitHistoryService>.value(value: visitHistoryService),
          ChangeNotifierProvider(create: (_) => UserPreferenceProvider()),
          Provider<PlaceRecommendationService>.value(value: placeRecommendationService),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<LocationProvider>.value(value: locationProvider),
          ChangeNotifierProvider<RouteProvider>.value(value: routeProvider),
          ChangeNotifierProvider<NavigationProvider>.value(value: navigationProvider),
          ChangeNotifierProxyProvider<AuthProvider, ScheduleProvider>(
            create: (context) => ScheduleProvider(
              authProvider: context.read<AuthProvider>(),
            ),
            update: (context, auth, previous) => ScheduleProvider(
              authProvider: auth,
            ),
          ),
          ChangeNotifierProvider(create: (_) => RouteProvider()),
        ],
        child: MyApp(isLoggedIn: token != null),
      ),
    );
  } catch (e) {
    print('Initialization error: $e');
    final authProvider = AuthProvider();
    runApp(
      MultiProvider(
        providers: [
          Provider<NavigationService>(create: (_) => NavigationService()),
          Provider<VisitHistoryService>(create: (_) => VisitHistoryService()),
          Provider<PlaceRecommendationService>(create: (_) => PlaceRecommendationService()),
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

class MyApp extends StatefulWidget {
  final bool isLoggedIn;

  const MyApp({
    Key? key,
    required this.isLoggedIn,
  }) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // 🔒 앱이 시작된 후에도 화면 회전 방지 설정 유지
    _lockOrientation();
  }

  void _lockOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  Widget build(BuildContext context) {
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
      home: widget.isLoggedIn ? const MainNavigation() : const AuthScreen(),
      // 🔒 앱 전체에 화면 회전 방지 설정 적용
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: 1.0, // 텍스트 크기 고정 (선택사항)
          ),
          child: child!,
        );
      },
    );
  }
}