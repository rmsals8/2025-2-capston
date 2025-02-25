// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

Future<void> initializeApp() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

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
      options: const FirebaseOptions(
        apiKey: "AIzaSyBcLQ2iyc7b46fQ1aJ6h5S-1NP-nj_uFEQ",
        appId: "1:769182070071:android:618adb2812fb60eb1e16b2",
        messagingSenderId: "769182070071",
        projectId: "capston-design-7344b",
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

    runApp(
      MultiProvider(
        providers: [
          Provider<NavigationService>.value(value: navigationService),
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
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<LocationProvider>(create: (_) => LocationProvider()),
          ChangeNotifierProvider<ScheduleProvider>(create: (_) => ScheduleProvider()),
          ChangeNotifierProvider<RouteProvider>(create: (_) => RouteProvider()),
          ChangeNotifierProvider<NavigationProvider>(
            create: (context) => NavigationProvider(
            ),
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