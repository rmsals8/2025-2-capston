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
import 'package:trip_helper/services/navigation_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final LatLng defaultLocation = const LatLng(37.5665, 126.9780);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocationProvider>(
          create: (_) => LocationProvider(),
        ),
        ChangeNotifierProvider<NavigationProvider>(
          create: (context) => NavigationProvider(

          ),
        ),
      ],
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            const HomeScreen(),
            const RouteGenerationScreen(),
            NavigationScreen(
              startLocation: defaultLocation,
              endLocation: const LatLng(37.5665, 126.9780),
            ),
            const ProfileHistoryScreen(),
          ],
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
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}