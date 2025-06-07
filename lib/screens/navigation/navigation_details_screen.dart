import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;

// 🆕 새로 추가된 import들
import '../../services/smart_directions_service.dart';
import '../../services/google_transit_service.dart';
import '../../widgets/transport_mode_selector.dart';
import '../../widgets/route_selection_bottom_sheet.dart';
import '../../widgets/detailed_transit_steps_widget.dart';
import '../../models/transport_mode.dart';
import '../../models/route_info.dart';

// 대중교통 정보를 저장할 클래스 (기존 유지)
class TransitDetails {
  final String line;
  final String vehicle;
  final String departureStop;
  final String arrivalStop;
  final int numStops;
  final String headSign;

  TransitDetails({
    required this.line,
    required this.vehicle,
    required this.departureStop,
    required this.arrivalStop,
    required this.numStops,
    required this.headSign,
  });
}

class NavigationDetailsScreen extends StatefulWidget {
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final String startName;
  final String endName;
  final String transportMode;

  const NavigationDetailsScreen({
    Key? key,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.startName,
    required this.endName,
    required this.transportMode,
  }) : super(key: key);

  @override
  State<NavigationDetailsScreen> createState() => _NavigationDetailsScreenState();
}

class _NavigationDetailsScreenState extends State<NavigationDetailsScreen> {
  // 🔒 기존 변수들 (변경 없음)
  bool _mapInitialized = false;
  bool _isRouteInitialized = false;
  bool _showFullInstructions = false;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<String> _instructions = [];
  List<TransitDetails> _transitDetails = [];
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  String get apiKey => dotenv.dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  bool _isLoading = true;
  String? _errorMessage;
  String _transportMode = '';

  // 경로 정보 (기존)
  List<LatLng> _routePoints = [];
  String _routeSummary = '';
  int _estimatedDuration = 0;
  double _estimatedDistance = 0;

  // 보정된 좌표 저장 (기존)
  late double _correctedStartLat;
  late double _correctedStartLon;
  late double _correctedEndLat;
  late double _correctedEndLon;

  // 🆕 새로 추가된 변수들
  final SmartDirectionsService _smartDirectionsService = SmartDirectionsService();
  final GoogleTransitService _googleTransitService = GoogleTransitService();

  TransportMode _selectedTransportMode = TransportMode.driving;
  List<RouteInfo> _routeOptions = [];
  List<GoogleTransitRoute> _transitRouteDetails = [];
  int _selectedRouteIndex = 0;
  bool _isSearchingRoutes = false;
  Timer? _realTimeUpdateTimer;

  // 실시간 정보
  double _remainingDistance = 0.0;
  int _remainingTime = 0;
  String _nextInstruction = '';

  @override
  void initState() {
    super.initState();
    _transportMode = widget.transportMode;

    // 🆕 교통수단 초기값 설정
    _selectedTransportMode = _getTransportModeFromString(widget.transportMode);

    // 좌표 보정 - 기존 로직 유지
    _correctCoordinates();

    // 화면 구성 후 초기화 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMap();
    });
  }

  @override
  void dispose() {
    // 구독 해제 (기존 + 추가)
    _positionStreamSubscription?.cancel();
    _realTimeUpdateTimer?.cancel();

    // 컨트롤러 안전하게 해제
    if (_mapController != null) {
      _mapController = null;
    }

    super.dispose();
  }

  // 🆕 문자열을 TransportMode로 변환
  TransportMode _getTransportModeFromString(String mode) {
    switch (mode.toLowerCase()) {
      case 'walking':
      case 'walk':
        return TransportMode.walking;
      case 'transit':
      case 'publictransport':
        return TransportMode.transit;
      case 'driving':
      case 'car':
      default:
        return TransportMode.driving;
    }
  }

  // 🔒 기존 메서드들 (변경 없음) - 1. 좌표 보정 로직
  void _correctCoordinates() {
    final double origStartLat = widget.startLat;
    final double origStartLon = widget.startLon;
    final double origEndLat = widget.endLat;
    final double origEndLon = widget.endLon;

    print('원본 좌표: 출발($origStartLat, $origStartLon), 도착($origEndLat, $origEndLon)');

    bool startInKoreaRange = _isInKoreanRange(origStartLat, origStartLon);
    bool endInKoreaRange = _isInKoreanRange(origEndLat, origEndLon);

    bool needSwap = _needCoordinateSwap(origStartLat, origStartLon) ||
        _needCoordinateSwap(origEndLat, origEndLon);

    print('좌표 상태: 한국 범위(출발: $startInKoreaRange, 도착: $endInKoreaRange), 스왑 필요: $needSwap');

    double tempStartLat = origStartLat;
    double tempStartLon = origStartLon;
    double tempEndLat = origEndLat;
    double tempEndLon = origEndLon;

    if (needSwap) {
      double temp = tempStartLat;
      tempStartLat = tempStartLon;
      tempStartLon = temp;

      temp = tempEndLat;
      tempEndLat = tempEndLon;
      tempEndLon = temp;

      print('스왑 후 좌표: 출발($tempStartLat, $tempStartLon), 도착($tempEndLat, $tempEndLon)');
    }

    _correctedStartLat = _normalizeCoordinate(tempStartLat, true);
    _correctedStartLon = _normalizeCoordinate(tempStartLon, false);
    _correctedEndLat = _normalizeCoordinate(tempEndLat, true);
    _correctedEndLon = _normalizeCoordinate(tempEndLon, false);

    bool isStartValid = _isValidKoreanCoordinate(_correctedStartLat, _correctedStartLon);
    bool isEndValid = _isValidKoreanCoordinate(_correctedEndLat, _correctedEndLon);

    print('정규화 후 최종 좌표:');
    print('출발: $_correctedStartLat, $_correctedStartLon (유효: $isStartValid)');
    print('도착: $_correctedEndLat, $_correctedEndLon (유효: $isEndValid)');

    if (!isStartValid || !isEndValid) {
      print('경고: 유효하지 않은 좌표 감지. 기본 울산 좌표로 설정합니다.');

      if (!isStartValid) {
        _correctedStartLat = 35.5384;
        _correctedStartLon = 129.2582;
      }

      if (!isEndValid) {
        _correctedEndLat = 35.5361;
        _correctedEndLon = 129.3114;
      }

      print('기본 좌표로 대체: 출발($_correctedStartLat, $_correctedStartLon), 도착($_correctedEndLat, $_correctedEndLon)');
    }
  }

  bool _isInKoreanRange(double lat, double lon) {
    return (lat >= 33.0 && lat <= 39.0 && lon >= 124.0 && lon <= 132.0);
  }

  bool _needCoordinateSwap(double lat, double lon) {
    return (lat > 100 || (lon > 33.0 && lon < 39.0));
  }

  bool _isValidKoreanCoordinate(double lat, double lon) {
    return lat >= 33.0 && lat <= 39.0 && lon >= 124.0 && lon <= 132.0;
  }

  double _normalizeCoordinate(double value, bool isLatitude) {
    if (isLatitude && value >= -90 && value <= 90) return value;
    if (!isLatitude && value >= -180 && value <= 180) return value;

    if (value > 1000) {
      int digits = value.toInt().toString().length;

      if (digits >= 8) {
        return value / 10000000.0;
      } else if (digits >= 6) {
        return value / 1000000.0;
      } else if (digits >= 5) {
        return value / 100000.0;
      }
    }

    return isLatitude ? 35.5384 : 129.2582;
  }

  // 🔒 기존 메서드 (변경 없음) - 2. 지도 초기화 로직
  Future<void> _initMap() async {
    bool hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      setState(() {
        _errorMessage = '위치 권한이 없습니다.';
        _isLoading = false;
      });
      return;
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      _startLocationTracking();

      // 🆕 스마트 경로 검색 시작
      if (!_isRouteInitialized) {
        await _searchMultipleRoutes();
        _isRouteInitialized = true;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '위치를 가져오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // 🔒 기존 메서드 (변경 없음) - 3. 카메라 이동 로직
  void _moveMapCamera() {
    if (_mapController == null || !mounted) return;

    try {
      final centerLat = (_correctedStartLat + _correctedEndLat) / 2;
      final centerLon = (_correctedStartLon + _correctedEndLon) / 2;

      final adjustedCenterLat = centerLat + 10;

      final distance = _calculateDistance(
          _correctedStartLat, _correctedStartLon,
          _correctedEndLat, _correctedEndLon
      );

      double zoomLevel;
      if (distance < 1) zoomLevel = 16.0;
      else if (distance < 3) zoomLevel = 15.0;
      else if (distance < 7) zoomLevel = 14.0;
      else if (distance < 15) zoomLevel = 13.0;
      else if (distance < 30) zoomLevel = 12.0;
      else if (distance < 70) zoomLevel = 11.0;
      else zoomLevel = 10.0;

      print('지도 이동(남쪽 조정): 중심점($adjustedCenterLat, $centerLon), 거리(${distance.toStringAsFixed(2)}km), 줌($zoomLevel)');

      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(adjustedCenterLat, centerLon),
            zoom: zoomLevel,
            tilt: 10.0,
          ),
        ),
      );

      Future.delayed(Duration(milliseconds: 500), () {
        if (_mapController != null && mounted) {
          _fitMapToBounds();
        }
      });
    } catch (e) {
      print('카메라 이동 오류: $e');
    }
  }

  void _fitMapToBounds() {
    if (_mapController == null || !mounted) return;

    try {
      List<LatLng> boundPoints = [];

      if (_routePoints.isNotEmpty) {
        boundPoints.addAll(_routePoints);
      } else {
        boundPoints.add(LatLng(_correctedStartLat, _correctedStartLon));
        boundPoints.add(LatLng(_correctedEndLat, _correctedEndLon));
      }

      double minLat = double.infinity;
      double maxLat = -double.infinity;
      double minLng = double.infinity;
      double maxLng = -double.infinity;

      for (var point in boundPoints) {
        minLat = min(minLat, point.latitude);
        maxLat = max(maxLat, point.latitude);
        minLng = min(minLng, point.longitude);
        maxLng = max(maxLng, point.longitude);
      }

      double latDiff = maxLat - minLat;
      double lngDiff = maxLng - minLng;

      if (latDiff < 0.01) {
        double center = (maxLat + minLat) / 2;
        minLat = center - 0.005;
        maxLat = center + 0.005;
      }

      if (lngDiff < 0.01) {
        double center = (maxLng + minLng) / 2;
        minLng = center - 0.005;
        maxLng = center + 0.005;
      }

      double paddingTop = 0.008;
      double paddingBottom = 0.002;
      double paddingSide = 0.005;

      double verticalOffset = -0.05;

      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat - paddingBottom + verticalOffset, minLng - paddingSide),
        northeast: LatLng(maxLat + paddingTop + verticalOffset, maxLng + paddingSide),
      );

      print('경계 설정(아래로 조정): 남서(${bounds.southwest.latitude}, ${bounds.southwest.longitude}), 북동(${bounds.northeast.latitude}, ${bounds.northeast.longitude})');

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50.0),
      ).catchError((e) {
        print('경계 설정 오류: $e. 기본 위치로 이동합니다.');
        _simpleCameraMove();
      });
    } catch (e) {
      print('경계 계산 오류: $e. 기본 위치로 이동합니다.');
      _simpleCameraMove();
    }
  }

  void _simpleCameraMove() {
    if (_mapController == null || !mounted) return;

    try {
      final centerLat = (_correctedStartLat + _correctedEndLat) / 2;
      final centerLon = (_correctedStartLon + _correctedEndLon) / 2;

      final adjustedCenterLat = centerLat + 0.005;

      print('단순 카메라 이동(남쪽 조정): 중심점($adjustedCenterLat, $centerLon)');

      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(adjustedCenterLat, centerLon),
            zoom: 13.0,
            tilt: 10.0,
          ),
        ),
      );
    } catch (e) {
      print('단순 카메라 이동마저 실패: $e');
    }
  }

  // 🔒 기존 메서드 (변경 없음) - 6. 현재 위치 추적 함수
  void _startLocationTracking() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
        _updateCurrentLocationMarker();
      });

      // 🆕 실시간 정보 업데이트
      _updateRemainingTimeDistance();
    });

    // 🆕 실시간 업데이트 타이머 시작
    _realTimeUpdateTimer = Timer.periodic(
      Duration(seconds: 30),
          (_) => _updateRemainingTimeDistance(),
    );
  }

  void _updateCurrentLocationMarker() {
    if (_currentPosition == null) return;

    _markers.removeWhere((marker) => marker.markerId.value == 'current');

    _markers.add(
      Marker(
        markerId: const MarkerId('current'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: '현재 위치'),
      ),
    );
  }

  // 🆕 새로 추가된 메서드들

  // 1. 교통수단 선택 위젯
  Widget _buildTransportModeSelector() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: TransportModeSelector(
          selectedMode: _selectedTransportMode,
          onModeChanged: _onTransportModeChanged,
        ),
      ),
    );
  }

  // 2. 교통수단 변경 핸들러
  void _onTransportModeChanged(TransportMode mode) async {
    if (_selectedTransportMode == mode) return;

    setState(() {
      _selectedTransportMode = mode;
      _transportMode = mode.name;
      _isSearchingRoutes = true;
      _routeOptions.clear();
      _transitRouteDetails.clear();
      _polylines.clear();
    });

    await _searchMultipleRoutes();
  }

  // 3. 다중 경로 검색 (핵심 기능)
  Future<void> _searchMultipleRoutes() async {
    if (_isSearchingRoutes) return;

    setState(() {
      _isSearchingRoutes = true;
      _errorMessage = null;
    });

    try {
      print('🔍 ${_selectedTransportMode.label} 경로 검색 시작...');

      final origin = LatLng(_correctedStartLat, _correctedStartLon);
      final destination = LatLng(_correctedEndLat, _correctedEndLon);

      if (_selectedTransportMode == TransportMode.transit) {
        // 대중교통: 상세 정보와 함께 검색
        final result = await _smartDirectionsService.getTransitRoutesWithDetails(
          origin,
          destination,
        );

        final routes = result['routes'] as List<RouteInfo>;
        final transitDetails = result['transitDetails'] as List<GoogleTransitRoute>;

        setState(() {
          _routeOptions = routes;
          _transitRouteDetails = transitDetails;
          _selectedRouteIndex = 0;
        });

        if (routes.isNotEmpty) {
          _updateMapWithSelectedRoute(routes.first);
          print('✅ 대중교통 ${routes.length}개 경로 + 상세정보 로드 완료');
        }
      } else {
        // 자동차, 도보: 일반 검색
        final routes = await _smartDirectionsService.getRoutes(
          origin,
          destination,
          _selectedTransportMode,
        );

        setState(() {
          _routeOptions = routes;
          _transitRouteDetails.clear();
          _selectedRouteIndex = 0;
        });

        if (routes.isNotEmpty) {
          _updateMapWithSelectedRoute(routes.first);
          print('✅ ${_selectedTransportMode.label} ${routes.length}개 경로 로드 완료');
        }
      }
    } catch (e) {
      print('❌ 경로 검색 실패: $e');
      setState(() {
        _errorMessage = '경로 검색 실패: $e';
      });

      // 폴백: 기존 방식으로 단일 경로 검색
      await _fetchRoute(_selectedTransportMode.name);
    } finally {
      setState(() {
        _isSearchingRoutes = false;
      });
    }
  }

  // 4. 선택된 경로로 지도 업데이트
  void _updateMapWithSelectedRoute(RouteInfo route) {
    setState(() {
      _routePoints = route.points;
      _routeSummary = '${route.duration} • ${route.distance}';

      // 시간과 거리 파싱
      final durationMatch = RegExp(r'(\d+)').firstMatch(route.duration);
      final distanceMatch = RegExp(r'(\d+\.?\d*)').firstMatch(route.distance);

      _estimatedDuration = durationMatch != null ? int.parse(durationMatch.group(1)!) : 0;
      _estimatedDistance = distanceMatch != null ? double.parse(distanceMatch.group(1)!) : 0.0;
    });

    _updateMapWithRoute();
    _startRealTimeTracking();
  }

  // 5. 경로 옵션 보기 (하단 시트)
  void _showRouteOptions() {
    if (_routeOptions.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RouteSelectionBottomSheet(
        routes: _routeOptions,
        transportMode: _selectedTransportMode,
        transitRoutes: _transitRouteDetails.isNotEmpty ? _transitRouteDetails : null,
        onRouteSelected: (route) {
          final index = _routeOptions.indexOf(route);
          setState(() {
            _selectedRouteIndex = index;
          });
          _updateMapWithSelectedRoute(route);
          Navigator.pop(context);
        },
      ),
    );
  }

  // 6. 빠른 경로 선택 버튼들
  Widget _buildQuickRouteSelector() {
    if (_routeOptions.length <= 1) return SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _routeOptions.length,
        itemBuilder: (context, index) {
          final route = _routeOptions[index];
          final isSelected = index == _selectedRouteIndex;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedRouteIndex = index;
              });
              _updateMapWithSelectedRoute(route);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _selectedTransportMode.color : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedTransportMode.color,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '옵션 ${index + 1}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : _selectedTransportMode.color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    route.duration.split(' • ')[0],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 7. 대중교통 정보 패널
  Widget _buildTransitInfoPanel() {
    if (_selectedTransportMode != TransportMode.transit ||
        _transitRouteDetails.isEmpty ||
        _selectedRouteIndex >= _transitRouteDetails.length) {
      return SizedBox.shrink();
    }

    final transitRoute = _transitRouteDetails[_selectedRouteIndex];

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_transit, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    transitRoute.summary.isNotEmpty ? transitRoute.summary : '대중교통 경로',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.list_alt),
                  onPressed: () => _showTransitDetails(transitRoute),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                if (transitRoute.totalFare.isNotEmpty) ...[
                  Icon(Icons.payments, size: 16, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    '요금: ${transitRoute.totalFare}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 16),
                ],
                Icon(Icons.sync_alt, size: 16, color: Colors.blue),
                SizedBox(width: 4),
                Text(
                  '환승: ${_countTransfers(transitRoute)}회',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 8. 대중교통 환승 횟수 계산
  int _countTransfers(GoogleTransitRoute transitRoute) {
    int transferCount = 0;
    for (int i = 0; i < transitRoute.steps.length - 1; i++) {
      final currentStep = transitRoute.steps[i];
      final nextStep = transitRoute.steps[i + 1];

      if (currentStep.mode == 'TRANSIT' && nextStep.mode == 'TRANSIT') {
        transferCount++;
      }
    }
    return transferCount;
  }

  // 9. 대중교통 상세 정보 표시
  void _showTransitDetails(GoogleTransitRoute transitRoute) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DetailedTransitStepsWidget(
        route: _routeOptions[_selectedRouteIndex],
        steps: transitRoute.steps,
      ),
    );
  }

  // 10. 실시간 정보 카드
  Widget _buildRealTimeInfo() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.my_location,
              color: _selectedTransportMode.color,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '실시간 정보',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _remainingDistance > 0
                        ? '남은 거리: ${_remainingDistance.toStringAsFixed(1)}km • 예상 시간: ${_remainingTime}분'
                        : _routeSummary,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _updateRemainingTimeDistance,
            ),
          ],
        ),
      ),
    );
  }

  // 11. 실시간 추적 시작
  void _startRealTimeTracking() {
    _updateRemainingTimeDistance();
  }

  // 12. 남은 거리와 시간 업데이트
  void _updateRemainingTimeDistance() {
    if (_currentPosition == null || _routePoints.isEmpty) return;

    final currentLocation = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final destination = LatLng(_correctedEndLat, _correctedEndLon);

    // 직선 거리 계산
    final distance = _calculateDistance(
      currentLocation.latitude, currentLocation.longitude,
      destination.latitude, destination.longitude,
    );

    setState(() {
      _remainingDistance = distance;

      // 교통수단별 예상 시간 계산
      switch (_selectedTransportMode) {
        case TransportMode.walking:
          _remainingTime = (distance * 12).round(); // 도보: km당 12분
          break;
        case TransportMode.transit:
          _remainingTime = (distance * 3).round(); // 대중교통: km당 3분
          break;
        case TransportMode.driving:
          _remainingTime = (distance * 1.5).round(); // 자동차: km당 1.5분
          break;
      }

      // 다음 안내 업데이트
      if (_instructions.isNotEmpty) {
        _nextInstruction = _instructions.first;
      }
    });
  }

  // 🔒 기존 메서드 (기능 확장) - 경로 데이터 가져오기
  Future<void> _fetchRoute([String? transportMode]) async {
    if (_isRouteInitialized && transportMode == null) return;

    try {
      if (transportMode != null) {
        _transportMode = transportMode;
        _selectedTransportMode = _getTransportModeFromString(transportMode);
      }

      String mode;
      if (_transportMode == 'DRIVING') {
        mode = 'driving';
      } else if (_transportMode == 'TRANSIT') {
        mode = 'transit';
      } else {
        mode = 'walking';
      }

      if (!_isValidKoreanCoordinate(_correctedStartLat, _correctedStartLon) ||
          !_isValidKoreanCoordinate(_correctedEndLat, _correctedEndLon)) {
        print('경고: API 호출 전 좌표 유효성 검사 실패, 기본 좌표 사용');

        _correctedStartLat = 35.5384;
        _correctedStartLon = 129.2582;
        _correctedEndLat = 35.5361;
        _correctedEndLon = 129.3114;
      }

      final startLatStr = _correctedStartLat.toStringAsFixed(6);
      final startLonStr = _correctedStartLon.toStringAsFixed(6);
      final endLatStr = _correctedEndLat.toStringAsFixed(6);
      final endLonStr = _correctedEndLon.toStringAsFixed(6);

      print('API 요청 좌표: 출발($startLatStr, $startLonStr), 도착($endLatStr, $endLonStr)');

      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?'
              'origin=$startLatStr,$startLonStr'
              '&destination=$endLatStr,$endLonStr'
              '&mode=$mode'
              '&language=ko'
              '&key=$apiKey'
      );

      print('API 요청 URL: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('API 응답 상태: ${data['status']}');
        print('API 오류 메시지: ${data['error_message'] ?? "없음"}');

        if (data['status'] == 'OK') {
          PolylinePoints polylinePoints = PolylinePoints();
          List<PointLatLng> decodedPolyline =
          polylinePoints.decodePolyline(data['routes'][0]['overview_polyline']['points']);

          setState(() {
            _routePoints = decodedPolyline
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();

            _routeSummary = data['routes'][0]['summary'] ?? '경로 정보';
            _estimatedDuration = data['routes'][0]['legs'][0]['duration']['value'] ~/ 60;
            _estimatedDistance = data['routes'][0]['legs'][0]['distance']['value'] / 1000;

            _instructions = [];
            _transitDetails = [];

            for (var step in data['routes'][0]['legs'][0]['steps']) {
              String instruction = step['html_instructions'] ?? '';
              instruction = instruction.replaceAll(RegExp(r'<[^>]*>'), ' ');
              _instructions.add(instruction);

              if (step['travel_mode'] == 'TRANSIT' && step['transit_details'] != null) {
                final transitDetails = step['transit_details'];
                final line = transitDetails['line']?['short_name'] ??
                    transitDetails['line']?['name'] ?? '노선 정보 없음';
                final vehicle = transitDetails['line']?['vehicle']?['name'] ?? '대중교통';
                final departureStop = transitDetails['departure_stop']?['name'] ?? '출발지';
                final arrivalStop = transitDetails['arrival_stop']?['name'] ?? '도착지';
                final numStops = transitDetails['num_stops'] ?? 0;
                final headSign = transitDetails['headsign'] ?? '';

                String transitInstruction = '🚍 $vehicle $line번 - $departureStop에서 승차, $arrivalStop에서 하차 (정거장 $numStops개)';
                if (headSign.isNotEmpty) {
                  transitInstruction += ' ($headSign 방향)';
                }
                _instructions.add(transitInstruction);

                _transitDetails.add(TransitDetails(
                  line: line,
                  vehicle: vehicle,
                  departureStop: departureStop,
                  arrivalStop: arrivalStop,
                  numStops: numStops,
                  headSign: headSign,
                ));
              }
            }
            _errorMessage = null;
          });

          _updateMapWithRoute();
        } else if (data['status'] == 'ZERO_RESULTS') {
          print('경로를 찾을 수 없습니다.');

          if (data.containsKey('available_travel_modes') &&
              data['available_travel_modes'] is List &&
              (data['available_travel_modes'] as List).isNotEmpty) {

            List<String> availableModes = List<String>.from(data['available_travel_modes']);
            String availableModesText = availableModes.map((mode) {
              switch (mode) {
                case 'DRIVING': return '자동차';
                case 'WALKING': return '도보';
                case 'BICYCLING': return '자전거';
                case 'TRANSIT': return '대중교통';
                default: return mode;
              }
            }).join(', ');

            setState(() {
              _errorMessage = '현재 선택한 이동 수단(${_getTransportModeText()})으로는 경로를 찾을 수 없습니다. '
                  '이용 가능한 이동 수단: $availableModesText';
            });

            if (availableModes.isNotEmpty && !availableModes.contains(_transportMode.toUpperCase()) && mounted) {
              String suggestedMode = _getModeFromApiMode(availableModes.first);

              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: Text('다른 이동 수단 이용'),
                    content: Text('${_getTransportModeText()} 모드로는 경로를 찾을 수 없습니다. ${_getTransportModeText(suggestedMode)} 모드로 시도하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        child: Text('취소'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          if (mounted) {
                            _fetchRoute(suggestedMode);
                          }
                        },
                        child: Text('확인'),
                      ),
                    ],
                  );
                },
              );
            }
          } else {
            setState(() {
              _errorMessage = '해당 이동 수단으로 경로를 찾을 수 없습니다. 직선 경로를 표시합니다.';
            });
          }

          _createDirectRoute();
        } else {
          print('API 오류: ${data['error_message'] ?? data['status']}. 직선 경로를 표시합니다.');

          _createDirectRoute();

          setState(() {
            if (data['status'] == 'REQUEST_DENIED') {
              _errorMessage = '경로 탐색 권한이 거부되었습니다. API 키를 확인해주세요. 직선 경로를 표시합니다.';
            } else {
              _errorMessage = '경로 탐색 실패: ${data['status']}. 직선 경로를 표시합니다.';
            }
          });
        }
      } else {
        _createDirectRoute();

        setState(() {
          _errorMessage = '경로 API 호출 실패: ${response.statusCode}. 직선 경로를 표시합니다.';
        });
      }
    } catch (e) {
      print('경로 가져오기 예외: $e');

      _createDirectRoute();

      setState(() {
        _errorMessage = '경로 가져오기 오류: $e. 직선 경로를 표시합니다.';
      });
    }
  }

  String _getModeFromApiMode(String apiMode) {
    switch (apiMode.toUpperCase()) {
      case 'DRIVING': return 'DRIVING';
      case 'WALKING': return 'WALK';
      case 'BICYCLING': return 'BICYCLING';
      case 'TRANSIT': return 'TRANSIT';
      default: return 'DRIVING';
    }
  }

  String _getTransportModeText([String? mode]) {
    String transportMode = mode ?? _transportMode;
    switch (transportMode) {
      case 'WALK':
        return '도보';
      case 'TRANSIT':
        return '대중교통';
      case 'DRIVING':
        return '자동차';
      case 'BICYCLING':
        return '자전거';
      default:
        return '이동';
    }
  }

  // 🔒 기존 메서드 (변경 없음) - 직선 경로 생성
  void _createDirectRoute() {
    print('직선 경로 생성');

    _routePoints = [
      LatLng(_correctedStartLat, _correctedStartLon),
      LatLng(_correctedEndLat, _correctedEndLon),
    ];

    double distance = _calculateDistance(
        _correctedStartLat, _correctedStartLon,
        _correctedEndLat, _correctedEndLon
    );

    int durationMinutes;
    if (_transportMode == 'WALK') {
      durationMinutes = (distance * 12).round();
    } else if (_transportMode == 'TRANSIT') {
      durationMinutes = (distance * 3).round();
    } else {
      durationMinutes = (distance * 1.5).round();
    }

    _routeSummary = '${widget.startName}에서 ${widget.endName}까지 직선 경로';
    _estimatedDuration = durationMinutes;
    _estimatedDistance = distance;

    _instructions = ['${widget.startName}에서 ${widget.endName}까지 이동합니다.'];

    _updateMapWithRoute();
  }

  // 🔒 기존 메서드 (기능 확장) - 경로 업데이트 및 지도 표시
  void _updateMapWithRoute() {
    print('경로 업데이트: ${_routePoints.length}개 포인트');
    if (_routePoints.isNotEmpty) {
      print('첫 포인트: ${_routePoints.first.latitude}, ${_routePoints.first.longitude}');
      print('마지막 포인트: ${_routePoints.last.latitude}, ${_routePoints.last.longitude}');
    }

    _markers.clear();

    _markers.add(
      Marker(
        markerId: const MarkerId('start'),
        position: LatLng(_correctedStartLat, _correctedStartLon),
        infoWindow: InfoWindow(title: widget.startName, snippet: '출발지'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        zIndex: 10,
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('end'),
        position: LatLng(_correctedEndLat, _correctedEndLon),
        infoWindow: InfoWindow(title: widget.endName, snippet: '도착지'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        zIndex: 10,
      ),
    );

    _updateCurrentLocationMarker();

    _polylines.clear();

    if (_routePoints.isNotEmpty) {
      Color routeColor = _selectedTransportMode.color;

      // 🆕 교통수단별 라인 스타일
      List<PatternItem> patterns = [];
      if (_selectedTransportMode == TransportMode.walking) {
        patterns = [PatternItem.dot, PatternItem.gap(10)];
      } else if (_selectedTransportMode == TransportMode.transit) {
        patterns = [PatternItem.dash(15), PatternItem.gap(10)];
      }

      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: routeColor,
          width: 5,
          patterns: patterns,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );

      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_highlight'),
          points: _routePoints,
          color: routeColor.withOpacity(0.3),
          width: 8,
          patterns: patterns,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

    setState(() {});

    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted && _mapController != null) {
        print('경로에 맞춰 지도 경계 조정...');
        _fitMapToBounds();
      }
    });
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (pi / 180);
  }

  double _toDegrees(double radian) {
    return radian * (180 / pi);
  }

  // 🔒 기존 UI 메서드들 (기능 확장)

  Widget _buildRouteInstructions() {
    if (_instructions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: const Text(
          '경로 안내 정보가 없습니다.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
          ),
        ),
      );
    }

    Widget _buildTransitSummary() {
      if (_transitDetails.isEmpty || _selectedTransportMode != TransportMode.transit) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '대중교통 이용 정보',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            ..._transitDetails.map((detail) {
              IconData vehicleIcon;
              Color vehicleColor;

              if (detail.vehicle.contains('버스')) {
                vehicleIcon = Icons.directions_bus;
                vehicleColor = Colors.green;
              } else if (detail.vehicle.contains('지하철') || detail.vehicle.contains('전철')) {
                vehicleIcon = Icons.subway;
                vehicleColor = Colors.blue;
              } else {
                vehicleIcon = Icons.directions_transit;
                vehicleColor = Colors.purple;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(vehicleIcon, color: vehicleColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${detail.vehicle} ${detail.line}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: vehicleColor,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${detail.departureStop} → ${detail.arrivalStop}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (detail.headSign.isNotEmpty)
                            Text(
                              '${detail.headSign} 방향 (정거장 ${detail.numStops}개)',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '상세 안내',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showFullInstructions ? Icons.expand_less : Icons.expand_more,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      _showFullInstructions = !_showFullInstructions;
                    });
                  },
                ),
              ],
            ),
          ),

          if (_transitDetails.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTransitSummary(),
            ),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          if (_showFullInstructions)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _instructions.length,
              itemBuilder: (context, index) {
                String instruction = _instructions[index].replaceAll(RegExp(r'<[^>]*>'), ' ').trim();

                bool isTransitInfo = instruction.startsWith('🚍');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isTransitInfo
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: isTransitInfo
                              ? const Icon(Icons.directions_transit, size: 14, color: Colors.blue)
                              : Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              )
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          instruction,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isTransitInfo ? FontWeight.w600 : FontWeight.normal,
                            color: isTransitInfo ? Colors.blue : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                _instructions.first.replaceAll(RegExp(r'<[^>]*>'), ' ').trim(),
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '${widget.startName} → ${widget.endName}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // 🆕 교통수단 아이콘과 경로 옵션 버튼
          Container(
            margin: EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Text(
                _selectedTransportMode.icon,
                style: TextStyle(fontSize: 20),
              ),
              onPressed: _showRouteOptions,
              tooltip: '경로 옵션 보기',
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 지도 위젯 (기존 유지)
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                35.907757,
                127.766922,
              ),
              zoom: 7.0,
              tilt: 10.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              print('지도 컨트롤러 생성됨');
              _mapController = controller;

              if (!_mapInitialized) {
                Future.delayed(Duration(milliseconds: 500), () {
                  if (mounted && _mapController != null) {
                    _moveMapCamera();
                    _mapInitialized = true;
                  }
                });
              }
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
            mapType: MapType.normal,
          ),

          // 🆕 상단: 교통수단 선택
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildTransportModeSelector(),
          ),

          // 🆕 중간: 빠른 경로 선택 (여러 옵션이 있을 때만)
          if (_routeOptions.length > 1)
            Positioned(
              top: 90,
              left: 0,
              right: 0,
              child: _buildQuickRouteSelector(),
            ),

          // 🆕 실시간 정보 카드
          Positioned(
            bottom: 200,
            left: 0,
            right: 0,
            child: _buildRealTimeInfo(),
          ),

          // 🆕 대중교통 정보 패널 (대중교통 모드일 때만)
          if (_selectedTransportMode == TransportMode.transit)
            Positioned(
              bottom: 140,
              left: 0,
              right: 0,
              child: _buildTransitInfoPanel(),
            ),

          // 하단 정보 패널들
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 안내 목록 패널 (기존)
                if (_instructions.isNotEmpty && !_isLoading) _buildRouteInstructions(),

                // 경로 정보 및 컨트롤 패널 (기존 + 확장)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: _instructions.isEmpty
                        ? const BorderRadius.vertical(top: Radius.circular(16))
                        : BorderRadius.zero,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 0,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🆕 오류 메시지 (개선)
                      if (_errorMessage != null && _routePoints.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // 🆕 제목 (교통수단 포함)
                      Row(
                        children: [
                          Text(
                            _selectedTransportMode.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_selectedTransportMode.label} 경로',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          // 🆕 검색 상태 표시
                          if (_isSearchingRoutes)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 🆕 경로 정보 (개선)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '총 거리: ${_estimatedDistance.toStringAsFixed(1)}km • 예상 시간: $_estimatedDuration분',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                          // 🆕 경로 개수 표시
                          if (_routeOptions.length > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _selectedTransportMode.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_routeOptions.length}개 옵션',
                                style: TextStyle(
                                  color: _selectedTransportMode.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 🆕 액션 버튼들 (개선)
                      Row(
                        children: [
                          // 전체 경로 보기 버튼
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_mapController != null) {
                                  _fitMapToBounds();
                                }
                              },
                              icon: const Icon(Icons.map, size: 16),
                              label: const Text('전체 경로'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[100],
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // 경로 옵션 보기 버튼
                          if (_routeOptions.length > 1) ...[
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: _showRouteOptions,
                                icon: const Icon(Icons.alt_route, size: 16),
                                label: const Text('다른 경로'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedTransportMode.color.withOpacity(0.1),
                                  foregroundColor: _selectedTransportMode.color,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // 길안내 시작 버튼
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // 🆕 실제 길안내 화면으로 이동하거나 실시간 추적 시작
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${_selectedTransportMode.label} 길안내를 시작합니다'),
                                    backgroundColor: _selectedTransportMode.color,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                _startRealTimeTracking();
                              },
                              icon: const Icon(Icons.navigation, size: 16),
                              label: const Text('길안내 시작'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedTransportMode.color,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 로딩 인디케이터 (기존 + 개선)
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isSearchingRoutes ? '최적 경로 검색 중...' : '지도 로딩 중...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // 🆕 플로팅 액션 버튼 (경로 옵션 빠른 접근)
      floatingActionButton: _routeOptions.length > 1 ? FloatingActionButton(
        onPressed: _showRouteOptions,
        backgroundColor: _selectedTransportMode.color,
        child: Stack(
          children: [
            const Icon(Icons.alt_route, color: Colors.white),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${_routeOptions.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}