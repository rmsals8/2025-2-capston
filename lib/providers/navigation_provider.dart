// lib/providers/navigation_provider.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_model.dart';
import '../models/navigation_status.dart';
import '../services/navigation_service.dart';
import '../models/route.dart' as app_route;
class NavigationProvider with ChangeNotifier {
  RouteModel? _selectedRoute;
  NavigationStatus? _navigationStatus;
  bool _isNavigating = false;
  String? _error;
  Timer? _navigationTimer;

  RouteModel? get selectedRoute => _selectedRoute;
  NavigationStatus? get navigationStatus => _navigationStatus;
  bool get isNavigating => _isNavigating;
  String? get error => _error;

  Future<void> initializeNavigation(app_route.Route route) async {
    try {
      _selectedRoute = RouteModel.fromRoute(route);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> startNavigation(LatLng startLocation) async {
    if (_selectedRoute == null) {
      throw Exception('선택된 경로가 없습니다.');
    }

    try {
      _error = null;
      _isNavigating = true;

      // 초기 내비게이션 상태 설정
      _navigationStatus = NavigationStatus(
        currentLocation: startLocation,
        bearing: 0,
        distanceToNextPoint: _calculateDistance(startLocation, _selectedRoute!.points.first),
        nextInstruction: '목적지로 이동합니다',
        distanceToDestination: _calculateTotalDistance(startLocation, _selectedRoute!.points),
        estimatedTimeToDestination: _calculateEstimatedTime(startLocation, _selectedRoute!.points),
        isOffRoute: false,
        speed: 0,
      );

      // 실시간 업데이트 시작
      _startNavigationUpdates();

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isNavigating = false;
      notifyListeners();
      throw Exception('내비게이션 시작 실패: $e');
    }
  }

  void _startNavigationUpdates() {
    _navigationTimer?.cancel();
    _navigationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isNavigating || _navigationStatus == null) {
        timer.cancel();
        return;
      }

      // 현재 위치 업데이트 (실제로는 위치 서비스에서 받아와야 함)
      final currentLocation = _navigationStatus!.currentLocation;
      final nextPoint = _getNextPoint(currentLocation);

      if (nextPoint != null) {
        final distance = _calculateDistance(currentLocation, nextPoint);
        final totalDistance = _calculateTotalDistance(currentLocation, _selectedRoute!.points);

        _navigationStatus = NavigationStatus(
          currentLocation: currentLocation,
          bearing: _calculateBearing(currentLocation, nextPoint),
          distanceToNextPoint: distance,
          nextInstruction: _getNextInstruction(distance),
          distanceToDestination: totalDistance,
          estimatedTimeToDestination: _calculateEstimatedTime(currentLocation, _selectedRoute!.points),
          isOffRoute: false,
          speed: 0, // 실제로는 위치 서비스에서 받아와야 함
        );

        notifyListeners();
      }
    });
  }

  double _calculateDistance(LatLng from, LatLng to) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((to.latitude - from.latitude) * p)/2 +
        c(from.latitude * p) * c(to.latitude * p) *
            (1 - c((to.longitude - from.longitude) * p))/2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  double _calculateBearing(LatLng from, LatLng to) {
    double lat1 = from.latitude * pi / 180;
    double lat2 = to.latitude * pi / 180;
    double dLon = (to.longitude - from.longitude) * pi / 180;

    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    double bearing = atan2(y, x);

    return (bearing * 180 / pi + 360) % 360;
  }

  double _calculateTotalDistance(LatLng current, List<LatLng> points) {
    double total = 0;
    LatLng previous = current;

    for (var point in points) {
      total += _calculateDistance(previous, point);
      previous = point;
    }

    return total;
  }

  int _calculateEstimatedTime(LatLng current, List<LatLng> points) {
    // 평균 속도를 40km/h로 가정
    double distance = _calculateTotalDistance(current, points);
    return (distance / 40 * 60).round(); // 분 단위로 반환
  }

  LatLng? _getNextPoint(LatLng current) {
    if (_selectedRoute == null || _selectedRoute!.points.isEmpty) return null;

    for (int i = 0; i < _selectedRoute!.points.length - 1; i++) {
      if (_calculateDistance(current, _selectedRoute!.points[i]) < 0.1) { // 100m 이내
        return _selectedRoute!.points[i + 1];
      }
    }

    return _selectedRoute!.points.first;
  }

  String _getNextInstruction(double distance) {
    if (distance < 0.1) {
      return "목적지 근처입니다";
    } else if (distance < 0.5) {
      return "500m 앞입니다";
    } else {
      return "${distance.toStringAsFixed(1)}km 앞입니다";
    }
  }

  Future<void> stopNavigation() async {
    _navigationTimer?.cancel();
    _isNavigating = false;
    _navigationStatus = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }
  Future<void> recalculateRoute() async {
    if (!_isNavigating || _navigationStatus == null || _selectedRoute == null) return;

    try {
      final currentLocation = _navigationStatus!.currentLocation;
      final destination = _selectedRoute!.points.last;

      // 현재 위치에서 목적지까지의 새로운 경로 계산
      List<LatLng> newPoints = [currentLocation];
      // 중간 포인트들 생성 (직선 경로)
      newPoints.addAll(_selectedRoute!.points.where((point) =>
      _calculateDistance(currentLocation, point) <
          _calculateDistance(currentLocation, destination)));
      newPoints.add(destination);

      // 새로운 RouteModel 생성
      _selectedRoute = RouteModel(
        id: _selectedRoute!.id,
        points: newPoints,
        distance: _calculateTotalDistance(currentLocation, newPoints),
        duration: _calculateEstimatedTime(currentLocation, newPoints),
        transportMode: _selectedRoute!.transportMode,
        routeColor: _selectedRoute!.routeColor,
        estimatedCost: _selectedRoute!.estimatedCost,
        summary: "재계산된 경로",
        instructions: ["목적지로 이동합니다"],
      );

      // 내비게이션 상태 업데이트
      _navigationStatus = NavigationStatus(
        currentLocation: currentLocation,
        bearing: _calculateBearing(currentLocation, newPoints[1]),
        distanceToNextPoint: _calculateDistance(currentLocation, newPoints[1]),
        nextInstruction: "경로가 재계산되었습니다",
        distanceToDestination: _calculateTotalDistance(currentLocation, newPoints),
        estimatedTimeToDestination: _calculateEstimatedTime(currentLocation, newPoints),
        isOffRoute: false,
        speed: _navigationStatus!.speed,
      );

      notifyListeners();
    } catch (e) {
      _error = '경로 재계산 실패: $e';
      notifyListeners();
    }
  }
}