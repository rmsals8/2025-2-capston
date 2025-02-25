// lib/screens/route/optimized_routes_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/schedule.dart';
import '../../models/route.dart' as app_route;
import '../../providers/route_provider.dart';
import '../../widgets/map/route_map.dart';
import '../../widgets/route/route_card.dart';
import '../navigation/navigation_screen.dart';
class OptimizedRoutesScreen extends StatefulWidget {
  final List<Schedule> fixedSchedules;
  final List<Map<String, dynamic>> flexibleSchedules;

  const OptimizedRoutesScreen({
    Key? key,
    required this.fixedSchedules,
    required this.flexibleSchedules,
  }) : super(key: key);

  @override
  State<OptimizedRoutesScreen> createState() => _OptimizedRoutesScreenState();
}

class _OptimizedRoutesScreenState extends State<OptimizedRoutesScreen> {
  int _selectedRouteIndex = 0;
  late final RouteProvider _routeProvider;

  @override
  void initState() {
    super.initState();
    _routeProvider = Provider.of<RouteProvider>(context, listen: false);
    _optimizeRoutes();
  }

  Future<void> _optimizeRoutes() async {
    try {
      await _routeProvider.getRecommendedRoutes(widget.flexibleSchedules);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('경로 최적화 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('최적화된 경로'),
      ),
      body: Consumer<RouteProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(child: Text('오류: ${provider.error}'));
          }

          final routes = provider.routes;
          if (routes.isEmpty) {
            return const Center(child: Text('가능한 경로가 없습니다.'));
          }

          return Column(
            children: [
              // 지도 표시
              Expanded(
                flex: 1,
                child: RouteMap(
                  routes: routes,
                  selectedRoute: routes[_selectedRouteIndex],
                  onRouteSelected: (route) {
                    setState(() {
                      _selectedRouteIndex = routes.indexOf(route);
                    });
                  },
                ),
              ),

              // 경로 옵션 목록
              Expanded(
                flex: 1,
                child: ListView.builder(
                  itemCount: routes.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final route = routes[index];
                    return RouteCard(
                      route: route,
                      isSelected: index == _selectedRouteIndex,
                      onTap: () {
                        setState(() {
                          _selectedRouteIndex = index;
                        });
                      },
                      onStartNavigation: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NavigationScreen(
                              startLocation: LatLng(
                                route.segments.first.startLat,
                                route.segments.first.startLon,
                              ),
                              endLocation: LatLng(
                                route.segments.last.endLat,
                                route.segments.last.endLon,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}