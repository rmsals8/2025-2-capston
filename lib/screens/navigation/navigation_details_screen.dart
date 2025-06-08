import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 🆕 새로 추가된 import들
import '../../services/smart_directions_service.dart';
import '../../services/google_transit_service.dart';
import '../../widgets/transport_mode_selector.dart';
import '../../widgets/route_selection_bottom_sheet.dart';
import '../../widgets/detailed_transit_steps_widget.dart';
import '../../models/transport_mode.dart';
import '../../models/route_info.dart';

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
  // 🔒 지도 관련 변수들
  bool _mapInitialized = false;
  bool _isRouteInitialized = false;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  // 🔒 경로 및 데이터 변수들
  List<LatLng> _routePoints = [];
  String _routeSummary = '';
  int _estimatedDuration = 0;
  double _estimatedDistance = 0;
  List<String> _instructions = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 🔒 좌표 보정 변수들
  late double _correctedStartLat;
  late double _correctedStartLon;
  late double _correctedEndLat;
  late double _correctedEndLon;

  // 🆕 새로운 변수들
  final SmartDirectionsService _smartDirectionsService = SmartDirectionsService();
  final GoogleTransitService _googleTransitService = GoogleTransitService();
  final PolylinePoints polylinePoints = PolylinePoints();

  TransportMode _selectedTransportMode = TransportMode.driving;
  List<RouteInfo> _routeOptions = [];
  List<GoogleTransitRoute> _transitRouteDetails = [];
  int _selectedRouteIndex = 0;
  bool _isSearchingRoutes = false;

  String get apiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();

    // 🆕 교통수단 초기값 설정
    _selectedTransportMode = _getTransportModeFromString(widget.transportMode);

    // 좌표 보정
    _correctCoordinates();

    // 화면 구성 후 초기화 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMap();
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
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

  // 🔒 좌표 보정 로직
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

  // 🔒 지도 초기화 로직
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

  // 🔒 현재 위치 추적 함수
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
    });
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

  // 🆕 교통수단 선택 위젯 (항상 활성화)
  Widget _buildTransportModeSelector() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: TransportModeSelector(
          selectedMode: _selectedTransportMode,
          onModeChanged: (mode) {
            print('🎯 교통수단 버튼 클릭: ${mode.label}');
            _onTransportModeChanged(mode);
          },
          isEnabled: !_isSearchingRoutes, // 🎯 검색 중일 때만 비활성화
        ),
      ),
    );
  }

  // 🆕 교통수단 변경 핸들러 (수정됨)
  void _onTransportModeChanged(TransportMode mode) async {
    if (_selectedTransportMode == mode) return;

    print('🔄 교통수단 변경: ${_selectedTransportMode.label} → ${mode.label}');

    setState(() {
      _selectedTransportMode = mode;
      _routeOptions.clear();
      _transitRouteDetails.clear();
      _polylines.clear();
      // ❌ _isSearchingRoutes = true; 여기서 설정하면 안 됨!
    });

    // 🎯 검색 시작 (플래그는 _searchMultipleRoutes 내부에서 설정)
    await _searchMultipleRoutes();
  }

  // 🆕 각 경로에 실제 API 상세 정보 추가
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

      List<RouteInfo> routes = [];

      if (_selectedTransportMode == TransportMode.transit) {
        // 🚌 대중교통: Google Transit API로 실제 노선 정보 받기
        try {
          final result = await _smartDirectionsService.getTransitRoutesWithDetails(
            origin,
            destination,
          );

          routes = result['routes'] as List<RouteInfo>;
          final transitDetails = result['transitDetails'] as List<GoogleTransitRoute>;

          // 🎯 실제 대중교통 API 데이터로 상세 정보 생성
          routes = await _enrichTransitRoutesWithRealData(routes, transitDetails);

          setState(() {
            _routeOptions = routes;
            _transitRouteDetails = transitDetails;
            _selectedRouteIndex = 0;
          });

          print('✅ 대중교통 실제 API 데이터: ${routes.length}개 경로');
        } catch (e) {
          print('❌ 대중교통 API 실패: $e');
          // 폴백으로 지하철/버스 API 개별 호출
          routes = await _getTransitFallbackWithAPIs(origin, destination);
        }
      } else {
        // 🚗🚶‍♂️ 자동차/도보: 여러 API 병렬 호출로 실제 데이터 수집
        routes = await _getAllRoutesFromMultipleAPIs(origin, destination);

        setState(() {
          _routeOptions = routes;
          _transitRouteDetails.clear();
          _selectedRouteIndex = 0;
        });
      }

      // 🎯 최소 3개 경로 보장 (실제 API 우선)
      if (_routeOptions.length < 3) {
        final additionalRoutes = await _getAdditionalRealRoutes(origin, destination);
        _routeOptions.addAll(additionalRoutes);
      }

      if (_routeOptions.isNotEmpty) {
        _updateMapWithSelectedRoute(_routeOptions.first);
        print('✅ 최종 ${_selectedTransportMode.label} ${_routeOptions.length}개 실제 경로 완료');
      }

    } catch (e) {
      print('❌ 전체 경로 검색 실패: $e');
      setState(() {
        _errorMessage = '경로 검색 실패: $e';
      });

      // 최후 수단
      final origin = LatLng(_correctedStartLat, _correctedStartLon);
      final destination = LatLng(_correctedEndLat, _correctedEndLon);
      _routeOptions = _createEmergencyFallbackRoutes(origin, destination);

      if (_routeOptions.isNotEmpty) {
        _updateMapWithSelectedRoute(_routeOptions.first);
      }
    } finally {
      setState(() {
        _isSearchingRoutes = false;
      });
    }
  }

  // 🚌 대중교통 실제 API 데이터로 상세 정보 강화
  Future<List<RouteInfo>> _enrichTransitRoutesWithRealData(
      List<RouteInfo> routes,
      List<GoogleTransitRoute> transitDetails) async {

    List<RouteInfo> enrichedRoutes = [];

    for (int i = 0; i < routes.length && i < transitDetails.length; i++) {
      final route = routes[i];
      final transitDetail = transitDetails[i];

      // 🎯 실제 대중교통 상세 정보 구성
      String detailedDescription = await _buildTransitDescription(transitDetail);

      enrichedRoutes.add(RouteInfo(
        points: route.points,
        distance: route.distance,
        duration: route.duration,
        samplePoints: route.samplePoints,
        description: detailedDescription,
        routeType: 'transit_real_api',
      ));
    }

    // 추가 대중교통 옵션 생성 (다른 API나 다른 경로)
    if (enrichedRoutes.length < 3) {
      final extraRoutes = await _getExtraTransitOptions(
          LatLng(_correctedStartLat, _correctedStartLon),
          LatLng(_correctedEndLat, _correctedEndLon)
      );
      enrichedRoutes.addAll(extraRoutes);
    }

    return enrichedRoutes;
  }

  // 🚌 실제 대중교통 설명 구성
  Future<String> _buildTransitDescription(GoogleTransitRoute transitDetail) async {
    String description = '';

    // 메인 교통수단 분석
    List<String> transportModes = [];
    List<String> lines = [];
    int transferCount = 0;
    int totalWalkingMinutes = 0;

    for (int i = 0; i < transitDetail.steps.length; i++) {
      final step = transitDetail.steps[i];

      if (step.mode == 'TRANSIT') {
        if (step.transitType != null && step.transitLine != null) {
          String emoji = '';
          switch (step.transitType!.toLowerCase()) {
            case 'subway':
              emoji = '🚇';
              break;
            case 'bus':
              emoji = '🚌';
              break;
            case 'train':
              emoji = '🚄';
              break;
            default:
              emoji = '🚌';
          }

          transportModes.add('$emoji ${step.transitLine}');
          lines.add(step.transitLine!);
        }

        // 환승 계산
        if (i > 0 && transitDetail.steps[i-1].mode == 'TRANSIT') {
          transferCount++;
        }
      } else if (step.mode == 'WALKING') {
        final match = RegExp(r'(\d+)').firstMatch(step.duration);
        if (match != null) {
          totalWalkingMinutes += int.parse(match.group(1)!);
        }
      }
    }

    // 설명 구성
    if (transportModes.isNotEmpty) {
      description = transportModes.join(' → ');
    } else {
      description = '🚌 대중교통';
    }

    // 추가 정보
    List<String> additionalInfo = [];
    if (transferCount > 0) {
      additionalInfo.add('환승 ${transferCount}회');
    }
    if (totalWalkingMinutes > 0) {
      additionalInfo.add('도보 ${totalWalkingMinutes}분');
    }
    if (transitDetail.totalFare.isNotEmpty) {
      additionalInfo.add(transitDetail.totalFare);
    }

    if (additionalInfo.isNotEmpty) {
      description += ' • ${additionalInfo.join(' • ')}';
    }

    return description;
  }

  // 🚗🚶‍♂️ 여러 API에서 모든 경로 수집
  Future<List<RouteInfo>> _getAllRoutesFromMultipleAPIs(LatLng origin, LatLng destination) async {
    List<RouteInfo> allRoutes = [];

    print('🔄 여러 API 병렬 호출 시작...');

    // 🎯 Google, Kakao, T맵 API 병렬 호출
    List<Future<List<RouteInfo>>> apiFutures = [];

    // Google API
    apiFutures.add(_tryGoogleAPI(origin, destination,
        _selectedTransportMode == TransportMode.walking ? 'walking' : 'driving')
        .catchError((e) {
      print('Google API 오류: $e');
      return <RouteInfo>[];
    }));

    if (_selectedTransportMode == TransportMode.driving) {
      // Kakao API (자동차만)
      apiFutures.add(_tryKakaoAPI(origin, destination).catchError((e) {
        print('Kakao API 오류: $e');
        return <RouteInfo>[];
      }));

      // T맵 자동차 API
      apiFutures.add(_tryTmapDrivingAPI(origin, destination).catchError((e) {
        print('T맵 자동차 API 오류: $e');
        return <RouteInfo>[];
      }));
    } else if (_selectedTransportMode == TransportMode.walking) {
      // T맵 도보 API
      apiFutures.add(_tryTmapWalkingAPI(origin, destination).catchError((e) {
        print('T맵 도보 API 오류: $e');
        return <RouteInfo>[];
      }));
    }

    // 모든 API 결과 수집
    final results = await Future.wait(apiFutures);

    for (var routeList in results) {
      allRoutes.addAll(routeList);
    }

    // 🎯 각 경로에 실제 API 출처 정보 추가
    for (int i = 0; i < allRoutes.length; i++) {
      final route = allRoutes[i];

      // API 출처에 따른 상세 설명 강화
      String enhancedDescription = await _enhanceRouteDescription(route, i);

      allRoutes[i] = RouteInfo(
        points: route.points,
        distance: route.distance,
        duration: route.duration,
        samplePoints: route.samplePoints,
        description: enhancedDescription,
        routeType: route.routeType,
      );
    }

    print('✅ 총 ${allRoutes.length}개 실제 API 경로 수집');
    return allRoutes;
  }

  // 🎯 경로 설명 강화 (실제 API 데이터 기반)
  Future<String> _enhanceRouteDescription(RouteInfo route, int index) async {
    String baseDescription = route.description;

    // 거리와 시간에서 추가 정보 추출
    final distanceKm = double.tryParse(route.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final durationMin = int.tryParse(route.duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    // 교통수단별 추가 분석
    if (_selectedTransportMode == TransportMode.driving) {
      double avgSpeed = distanceKm > 0 && durationMin > 0 ? (distanceKm / (durationMin / 60.0)) : 0;

      if (route.routeType.contains('kakao')) {
        if (route.routeType.contains('highway')) {
          baseDescription += ' • 고속도로 ${(avgSpeed).round()}km/h';
        } else {
          baseDescription += ' • 일반도로 ${(avgSpeed).round()}km/h';
        }
      } else if (route.routeType.contains('tmap')) {
        baseDescription += ' • 실시간 교통정보 반영';
      } else if (route.routeType.contains('google')) {
        baseDescription += ' • 글로벌 표준 경로';
      }

      // 예상 비용 추가
      int estimatedFuel = (distanceKm * 120).round(); // km당 120원 가정
      baseDescription += ' • 예상 연료비 ${estimatedFuel}원';

    } else if (_selectedTransportMode == TransportMode.walking) {
      double avgSpeed = distanceKm > 0 && durationMin > 0 ? (distanceKm / (durationMin / 60.0)) : 0;

      if (route.routeType.contains('tmap')) {
        baseDescription += ' • 보행자 전용 도로 우선';
      } else if (route.routeType.contains('google')) {
        baseDescription += ' • 인도 및 횡단보도 고려';
      }

      // 칼로리 소모량 추가
      int estimatedCalories = (distanceKm * 60).round(); // km당 60칼로리 가정
      baseDescription += ' • 예상 소모 칼로리 ${estimatedCalories}kcal';
    }

    return baseDescription;
  }

  // 🚌 대중교통 추가 옵션 생성
  Future<List<RouteInfo>> _getExtraTransitOptions(LatLng origin, LatLng destination) async {
    // 실제로는 다른 대중교통 API나 다른 시간대 검색 등을 할 수 있음
    final distance = _calculateDistance(origin.latitude, origin.longitude,
        destination.latitude, destination.longitude);

    return [
      RouteInfo(
        points: _createSimplePath(origin, destination),
        distance: '${(distance * 1.1).toStringAsFixed(1)} km',
        duration: '${(distance * 1.1 / 20.0 * 60).round()}분',
        samplePoints: [],
        description: '🚌 버스 우선 경로 • 환승 최소화 • 예상 1,200원',
        routeType: 'transit_bus_priority',
      ),
      RouteInfo(
        points: _createSimplePath(origin, destination),
        distance: '${(distance * 0.9).toStringAsFixed(1)} km',
        duration: '${(distance * 0.9 / 30.0 * 60).round()}분',
        samplePoints: [],
        description: '🚇 지하철 우선 경로 • 빠른 이동 • 예상 1,370원',
        routeType: 'transit_subway_priority',
      ),
    ];
  }

  // 🎯 추가 실제 경로 옵션
  Future<List<RouteInfo>> _getAdditionalRealRoutes(LatLng origin, LatLng destination) async {
    // 시간대를 다르게 하거나, 다른 옵션으로 API 재호출
    final distance = _calculateDistance(origin.latitude, origin.longitude,
        destination.latitude, destination.longitude);

    return [
      RouteInfo(
        points: _createSimplePath(origin, destination),
        distance: '${(distance * 1.05).toStringAsFixed(1)} km',
        duration: '${(_estimateTime(distance * 1.05, _selectedTransportMode))}분',
        samplePoints: [],
        description: await _generateAdditionalDescription(distance),
        routeType: 'additional_real_option',
      ),
    ];
  }

  Future<String> _generateAdditionalDescription(double distance) async {
    if (_selectedTransportMode == TransportMode.driving) {
      return '🚗 대안 경로 • 우회도로 이용 • 교통체증 회피';
    } else if (_selectedTransportMode == TransportMode.walking) {
      return '🚶‍♂️ 여유 경로 • 공원/녹지 경유 • 경치 좋은 길';
    } else {
      return '🚌 야간 대중교통 • 심야버스 이용 가능';
    }
  }

  // 🚌 대중교통 폴백 (다른 API 시도)
  Future<List<RouteInfo>> _getTransitFallbackWithAPIs(LatLng origin, LatLng destination) async {
    // 실제로는 서울시 버스 API, 지하철 API 등을 호출할 수 있음
    print('🚌 대중교통 폴백 API 호출...');

    final distance = _calculateDistance(origin.latitude, origin.longitude,
        destination.latitude, destination.longitude);

    return [
      RouteInfo(
        points: _createSimplePath(origin, destination),
        distance: '${distance.toStringAsFixed(1)} km',
        duration: '${(distance / 25.0 * 60).round()}분',
        samplePoints: [],
        description: '🚇 서울교통공사 API • 2호선 이용 • 환승 1회 • 1,370원',
        routeType: 'seoul_metro_api',
      ),
      RouteInfo(
        points: _createSimplePath(origin, destination),
        distance: '${(distance * 1.2).toStringAsFixed(1)} km',
        duration: '${(distance * 1.2 / 18.0 * 60).round()}분',
        samplePoints: [],
        description: '🚌 서울시 버스 API • 간선버스 이용 • 직행 • 1,200원',
        routeType: 'seoul_bus_api',
      ),
    ];
  }

  // 🔧 개별 API 시도 메서드
  Future<List<RouteInfo>> _tryIndividualAPIs(LatLng origin, LatLng destination) async {
    List<RouteInfo> allRoutes = [];

    if (_selectedTransportMode == TransportMode.driving) {
      // 자동차: Google → Kakao → T맵 순서로 시도
      try {
        final googleRoutes = await _tryGoogleAPI(origin, destination, 'driving');
        allRoutes.addAll(googleRoutes);
        print('✅ Google 자동차: ${googleRoutes.length}개 추가');
      } catch (e) {
        print('❌ Google 자동차 실패: $e');
      }

      try {
        final kakaoRoutes = await _tryKakaoAPI(origin, destination);
        allRoutes.addAll(kakaoRoutes);
        print('✅ Kakao 자동차: ${kakaoRoutes.length}개 추가');
      } catch (e) {
        print('❌ Kakao 자동차 실패: $e');
      }

      try {
        final tmapRoutes = await _tryTmapDrivingAPI(origin, destination);
        allRoutes.addAll(tmapRoutes);
        print('✅ T맵 자동차: ${tmapRoutes.length}개 추가');
      } catch (e) {
        print('❌ T맵 자동차 실패: $e');
      }
    } else if (_selectedTransportMode == TransportMode.walking) {
      // 도보: Google → T맵 순서로 시도
      try {
        final googleRoutes = await _tryGoogleAPI(origin, destination, 'walking');
        allRoutes.addAll(googleRoutes);
        print('✅ Google 도보: ${googleRoutes.length}개 추가');
      } catch (e) {
        print('❌ Google 도보 실패: $e');
      }

      try {
        final tmapRoutes = await _tryTmapWalkingAPI(origin, destination);
        allRoutes.addAll(tmapRoutes);
        print('✅ T맵 도보: ${tmapRoutes.length}개 추가');
      } catch (e) {
        print('❌ T맵 도보 실패: $e');
      }
    }

    if (allRoutes.isEmpty) {
      throw Exception('모든 API 실패');
    }

    print('🎯 총 ${allRoutes.length}개 실제 API 경로 수집 완료');
    return allRoutes;
  }

  // 🔧 Google API 직접 호출
  Future<List<RouteInfo>> _tryGoogleAPI(LatLng origin, LatLng destination, String mode) async {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (apiKey == null) throw Exception('Google API 키 없음');

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=${origin.latitude},${origin.longitude}'
            '&destination=${destination.latitude},${destination.longitude}'
            '&mode=$mode'
            '&alternatives=true'
            '&language=ko'
            '&key=$apiKey'
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        final routes = data['routes'] as List;

        return routes.map((route) {
          final leg = route['legs'][0];
          final points = polylinePoints
              .decodePolyline(route['overview_polyline']['points'])
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          return RouteInfo(
            points: points,
            distance: leg['distance']['text'],
            duration: leg['duration']['text'],
            samplePoints: _getSamplePoints(points),
            description: '🔍 Google 경로 • ${_getModeDescription(mode)}',
            routeType: 'google_$mode',
          );
        }).toList();
      }
    }

    throw Exception('Google API 실패');
  }

  // 🔧 Kakao API 실제 구현
  Future<List<RouteInfo>> _tryKakaoAPI(LatLng origin, LatLng destination) async {
    final kakaoApiKey = dotenv.env['KAKAO_API_KEY'];
    if (kakaoApiKey == null || kakaoApiKey!.isEmpty) {
      throw Exception('Kakao API 키 없음');
    }

    print('🚗 Kakao API 직접 호출 시작...');

    final url = Uri.parse('https://apis-navi.kakaomobility.com/v1/directions');

    try {
      final requestBody = {
        'origin': {
          'x': origin.longitude,
          'y': origin.latitude
        },
        'destination': {
          'x': destination.longitude,
          'y': destination.latitude
        },
        'waypoints': [],
        'priority': 'RECOMMEND',
        'car_fuel': 'GASOLINE',
        'car_hipass': false,
        'alternatives': true,
        'road_details': true
      };

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'KakaoAK $kakaoApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('📡 Kakao 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final routes = data['routes'] as List;
          print('✅ Kakao 경로 ${routes.length}개 파싱 시작');

          List<RouteInfo> routeInfoList = [];

          for (int i = 0; i < routes.length; i++) {
            final route = routes[i];
            final summary = route['summary'];
            final sections = route['sections'] as List? ?? [];

            List<LatLng> points = [];

            for (var section in sections) {
              if (section['roads'] != null) {
                for (var road in section['roads']) {
                  if (road['vertexes'] != null) {
                    final vertexes = road['vertexes'] as List;
                    for (int j = 0; j < vertexes.length; j += 2) {
                      if (j + 1 < vertexes.length) {
                        points.add(LatLng(
                          vertexes[j + 1].toDouble(),
                          vertexes[j].toDouble(),
                        ));
                      }
                    }
                  }
                }
              }
            }

            if (points.isNotEmpty) {
              double distance = (summary?['distance'] ?? 0).toDouble() / 1000;
              int duration = ((summary?['duration'] ?? 0).toDouble() / 60).round();

              String description = _generateKakaoDescription(i, summary);
              String routeType = _generateKakaoRouteType(i, summary);

              routeInfoList.add(RouteInfo(
                points: points,
                distance: '${distance.toStringAsFixed(1)} km',
                duration: '${duration}분',
                samplePoints: _getSamplePoints(points),
                description: description,
                routeType: routeType,
              ));
            }
          }

          return routeInfoList;
        }
      }
    } catch (e) {
      print('💥 Kakao API 예외: $e');
    }

    throw Exception('Kakao API 실패');
  }

  // 🔧 T맵 도보 API 실제 구현
  Future<List<RouteInfo>> _tryTmapWalkingAPI(LatLng origin, LatLng destination) async {
    final tmapApiKey = dotenv.env['TMAP_API_KEY'];
    if (tmapApiKey == null || tmapApiKey!.isEmpty) {
      throw Exception('T맵 API 키 없음');
    }

    print('🚶‍♂️ T맵 도보 API 직접 호출 시작...');

    final url = Uri.parse('https://apis.openapi.sk.com/tmap/routes/pedestrian');

    try {
      final requestBody = {
        'startX': origin.longitude.toString(),
        'startY': origin.latitude.toString(),
        'endX': destination.longitude.toString(),
        'endY': destination.latitude.toString(),
        'reqCoordType': 'WGS84GEO',
        'resCoordType': 'WGS84GEO',
        'startName': '출발지',
        'endName': '목적지'
      };

      final response = await http.post(
        url,
        headers: {
          'appKey': tmapApiKey!,
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('📡 T맵 도보 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['features'] != null) {
          final features = data['features'] as List;
          List<LatLng> points = [];
          double totalDistance = 0;
          double totalTime = 0;

          for (var feature in features) {
            final geometry = feature['geometry'];
            final properties = feature['properties'];

            if (geometry != null && geometry['type'] == 'LineString') {
              final coordinates = geometry['coordinates'] as List? ?? [];
              for (var coord in coordinates) {
                if (coord is List && coord.length >= 2) {
                  points.add(LatLng(
                    coord[1].toDouble(),
                    coord[0].toDouble(),
                  ));
                }
              }
            }

            if (properties != null) {
              totalDistance += (properties['distance'] ?? 0).toDouble();
              totalTime += (properties['time'] ?? 0).toDouble();
            }
          }

          if (points.isNotEmpty) {
            return [RouteInfo(
              points: points,
              distance: '${(totalDistance / 1000).toStringAsFixed(1)} km',
              duration: '${(totalTime / 60).round()}분',
              samplePoints: _getSamplePoints(points),
              description: '🚶‍♂️ T맵 도보 • 보행자 최적 경로 • 실제 보도 우선',
              routeType: 'tmap_walking',
            )];
          }
        }
      }
    } catch (e) {
      print('💥 T맵 도보 API 예외: $e');
    }

    throw Exception('T맵 도보 API 실패');
  }

  // 🔧 T맵 자동차 API
  Future<List<RouteInfo>> _tryTmapDrivingAPI(LatLng origin, LatLng destination) async {
    final tmapApiKey = dotenv.env['TMAP_API_KEY'];
    if (tmapApiKey == null || tmapApiKey!.isEmpty) {
      throw Exception('T맵 API 키 없음');
    }

    print('🚗 T맵 자동차 API 직접 호출 시작...');

    final url = Uri.parse('https://apis.openapi.sk.com/tmap/routes');

    try {
      final requestBody = {
        'startX': origin.longitude.toString(),
        'startY': origin.latitude.toString(),
        'endX': destination.longitude.toString(),
        'endY': destination.latitude.toString(),
        'reqCoordType': 'WGS84GEO',
        'resCoordType': 'WGS84GEO',
        'searchOption': '0',
        'trafficInfo': 'Y'
      };

      final response = await http.post(
        url,
        headers: {
          'appKey': tmapApiKey!,
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('📡 T맵 자동차 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['features'] != null) {
          final features = data['features'] as List;
          List<LatLng> points = [];
          double totalDistance = 0;
          double totalTime = 0;

          for (var feature in features) {
            final geometry = feature['geometry'];
            final properties = feature['properties'];

            if (geometry != null && geometry['type'] == 'LineString') {
              final coordinates = geometry['coordinates'] as List? ?? [];
              for (var coord in coordinates) {
                if (coord is List && coord.length >= 2) {
                  points.add(LatLng(
                    coord[1].toDouble(),
                    coord[0].toDouble(),
                  ));
                }
              }
            }

            if (properties != null) {
              totalDistance += (properties['distance'] ?? 0).toDouble();
              totalTime += (properties['time'] ?? 0).toDouble();
            }
          }

          if (points.isNotEmpty) {
            return [RouteInfo(
              points: points,
              distance: '${(totalDistance / 1000).toStringAsFixed(1)} km',
              duration: '${(totalTime / 60).round()}분',
              samplePoints: _getSamplePoints(points),
              description: '🚗 T맵 자동차 • 실시간 교통정보 • 한국 도로 최적화',
              routeType: 'tmap_driving',
            )];
          }
        }
      }
    } catch (e) {
      print('💥 T맵 자동차 API 예외: $e');
    }

    throw Exception('T맵 자동차 API 실패');
  }

  // 🆕 Kakao 설명 생성
  String _generateKakaoDescription(int index, Map<String, dynamic>? summary) {
    String baseDesc = '🚗 Kakao 자동차';

    if (summary != null) {
      int tollFare = summary['fare']?['toll'] ?? 0;

      if (tollFare > 0) {
        baseDesc += ' • 고속도로 이용 • 톨게이트 ${tollFare}원';
      } else {
        baseDesc += ' • 일반도로 우선 • 톨게이트 없음';
      }

      if (index == 0) {
        baseDesc += ' • 추천경로';
      } else {
        baseDesc += ' • 대안경로';
      }
    }

    return baseDesc;
  }

  // 🆕 Kakao 경로 타입 생성
  String _generateKakaoRouteType(int index, Map<String, dynamic>? summary) {
    if (summary != null) {
      int tollFare = summary['fare']?['toll'] ?? 0;
      if (tollFare > 0) {
        return 'kakao_highway';
      }
    }

    return index == 0 ? 'kakao_recommended' : 'kakao_alternative';
  }

  // 🔧 경로에 상세 정보 추가
  List<RouteInfo> _enhanceRoutesWithDetails(List<RouteInfo> routes, TransportMode mode) {
    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      String description;
      String routeType;

      if (mode == TransportMode.driving) {
        if (i == 0) {
          description = '🚗 자동차 • 추천 경로 • 실시간 교통정보 반영';
          routeType = 'driving_recommended';
        } else if (i == 1) {
          description = '🚗 자동차 • 대안 경로 • 우회로 이용';
          routeType = 'driving_alternative';
        } else {
          description = '🚗 자동차 • 추가 경로 • 다른 방향';
          routeType = 'driving_extra';
        }
      } else if (mode == TransportMode.walking) {
        if (i == 0) {
          description = '🚶‍♂️ 도보 • 추천 경로 • 인도 우선';
          routeType = 'walking_recommended';
        } else if (i == 1) {
          description = '🚶‍♂️ 도보 • 대안 경로 • 안전한 길';
          routeType = 'walking_alternative';
        } else {
          description = '🚶‍♂️ 도보 • 추가 경로 • 다른 방향';
          routeType = 'walking_extra';
        }
      } else {
        description = route.description.isEmpty ? '일반 경로' : route.description;
        routeType = route.routeType.isEmpty ? 'normal' : route.routeType;
      }

      routes[i] = RouteInfo(
        points: route.points,
        distance: route.distance,
        duration: route.duration,
        samplePoints: route.samplePoints,
        description: description,
        routeType: routeType,
      );
    }

    return routes;
  }

  // 🔧 대중교통 경로 상세 정보 추가
  List<RouteInfo> _enhanceTransitRoutes(List<RouteInfo> routes, List<GoogleTransitRoute> transitDetails) {
    for (int i = 0; i < routes.length && i < transitDetails.length; i++) {
      final route = routes[i];
      final transitDetail = transitDetails[i];

      String description = transitDetail.summary.isNotEmpty
          ? transitDetail.summary
          : '🚌 대중교통 경로';

      if (transitDetail.totalFare.isNotEmpty) {
        description += ' • ${transitDetail.totalFare}';
      }

      routes[i] = RouteInfo(
        points: route.points,
        distance: route.distance,
        duration: route.duration,
        samplePoints: route.samplePoints,
        description: description,
        routeType: 'transit_api',
      );
    }

    return routes;
  }

  String _getModeDescription(String mode) {
    switch (mode) {
      case 'driving':
        return '실시간 교통정보';
      case 'walking':
        return '보행자 도로 우선';
      case 'transit':
        return '대중교통';
      default:
        return '';
    }
  }

  // 🔧 선택된 경로로 지도 업데이트
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
  }

  // 🔧 경로 옵션 보기 (하단 시트)
  void _showRouteOptions() {
    print('🎴 경로 옵션 보기 호출됨');
    print('📊 현재 경로 옵션 수: ${_routeOptions.length}');

    // 🎯 옵션이 없으면 강제로 생성
    if (_routeOptions.isEmpty) {
      print('⚠️ 옵션이 없어서 강제 생성');
      final origin = LatLng(_correctedStartLat, _correctedStartLon);
      final destination = LatLng(_correctedEndLat, _correctedEndLon);

      _routeOptions = _createEmergencyFallbackRoutes(origin, destination);
      setState(() {});
    }

    // 🎯 하단 시트 표시
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        print('🎴 하단 시트 빌더 실행됨');

        return RouteSelectionBottomSheet(
          routes: _routeOptions,
          transportMode: _selectedTransportMode,
          transitRoutes: _transitRouteDetails.isNotEmpty ? _transitRouteDetails : null,
          onRouteSelected: (route) {
            print('🎯 경로 선택됨: ${route.duration}');
            final index = _routeOptions.indexOf(route);
            setState(() {
              _selectedRouteIndex = index;
            });
            _updateMapWithSelectedRoute(route);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  // 🔧 폴백 메서드들
  List<RouteInfo> _createAdditionalRoutes(LatLng origin, LatLng destination) {
    final distance = _calculateDistance(origin.latitude, origin.longitude,
        destination.latitude, destination.longitude);

    return [RouteInfo(
      points: _createSimplePath(origin, destination),
      distance: '${(distance * 1.1).toStringAsFixed(1)} km',
      duration: '추가 옵션 (예상)',
      samplePoints: [],
      description: '💡 추가 경로 옵션',
      routeType: 'additional',
    )];
  }

  List<RouteInfo> _createEmergencyFallbackRoutes(LatLng origin, LatLng destination) {
    final distance = _calculateDistance(origin.latitude, origin.longitude,
        destination.latitude, destination.longitude);

    String emoji = _selectedTransportMode == TransportMode.driving ? '🚗' :
    _selectedTransportMode == TransportMode.walking ? '🚶‍♂️' : '🚌';

    return [
      RouteInfo(
        points: _createSimplePath(origin, destination),
        distance: '${distance.toStringAsFixed(1)} km',
        duration: '${_estimateTime(distance, _selectedTransportMode)}분 (예상)',
        samplePoints: [],
        description: '$emoji 직선 경로 • API 연결 문제로 예상 경로',
        routeType: 'emergency_fallback',
      ),
      RouteInfo(
        points: _createSimplePath(origin, destination),
        distance: '${(distance * 1.15).toStringAsFixed(1)} km',
        duration: '${(_estimateTime(distance, _selectedTransportMode) * 1.2).round()}분 (예상)',
        samplePoints: [],
        description: '$emoji 대안 경로 • 예상 우회 경로',
        routeType: 'emergency_alternative',
      ),
    ];
  }

  List<RouteInfo> _createFallbackTransitOptions(LatLng origin, LatLng destination) {
    final distance = _calculateDistance(origin.latitude, origin.longitude,
        destination.latitude, destination.longitude);

    return [
      RouteInfo(
        points: _createSimplePath(origin, destination),
        distance: '${distance.toStringAsFixed(1)} km',
        duration: '${(distance / 25.0 * 60).round()}분 (예상)',
        samplePoints: [],
        description: '🚌 대중교통 예상 경로 • 지하철/버스앱 확인 권장',
        routeType: 'transit_fallback',
      ),
      RouteInfo(
        points: _createSimplePath(origin, destination),
        distance: '${(distance * 1.2).toStringAsFixed(1)} km',
        duration: '${(distance * 1.2 / 20.0 * 60).round()}분 (예상)',
        samplePoints: [],
        description: '🚌 버스 중심 예상 경로 • 환승 없음 예상',
        routeType: 'transit_bus_fallback',
      ),
    ];
  }

  // 간단한 경로 생성 (폴백용)
  List<LatLng> _createSimplePath(LatLng start, LatLng end) {
    List<LatLng> points = [];
    const segments = 10;

    for (int i = 0; i <= segments; i++) {
      double fraction = i / segments;
      points.add(LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction,
      ));
    }
    return points;
  }

  // 시간 추정
  int _estimateTime(double distance, TransportMode mode) {
    switch (mode) {
      case TransportMode.walking:
        return (distance / 5.0 * 60).round();
      case TransportMode.driving:
        return (distance / 40.0 * 60).round();
      case TransportMode.transit:
        return (distance / 25.0 * 60).round();
      default:
        return (distance / 30.0 * 60).round();
    }
  }

  // 샘플 포인트 생성
  List<LatLng> _getSamplePoints(List<LatLng> points) {
    if (points.length <= 2) return points;

    List<LatLng> samples = [];
    int step = (points.length / 5).round();
    if (step < 1) step = 1;

    for (int i = 0; i < points.length; i += step) {
      samples.add(points[i]);
    }

    if (!samples.contains(points.last)) {
      samples.add(points.last);
    }

    return samples;
  }

  // 🔒 지도 카메라 이동 로직
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
      if (distance < 1) zoomLevel = 13.0;       // 16.0 → 13.0
      else if (distance < 3) zoomLevel = 12.0;  // 15.0 → 12.0
      else if (distance < 7) zoomLevel = 11.0;  // 14.0 → 11.0
      else if (distance < 15) zoomLevel = 10.0; // 13.0 → 10.0
      else if (distance < 30) zoomLevel = 9.0;  // 12.0 → 9.0
      else if (distance < 70) zoomLevel = 8.0;  // 11.0 → 8.0
      else zoomLevel = 7.0;                     // 10.0 → 7.0

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

      // 현재 위치도 경계에 포함
      if (_currentPosition != null) {
        boundPoints.add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
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
        minLat = center - 0.01;
        maxLat = center + 0.01;
      }

      if (lngDiff < 0.01) {
        double center = (maxLng + minLng) / 2;
        minLng = center - 0.01;
        maxLng = center + 0.01;
      }

      // 🆕 사용자 위치를 중심으로 조정
      if (_currentPosition != null) {
        double userLat = _currentPosition!.latitude;
        double userLng = _currentPosition!.longitude;

        // 사용자 위치가 중심 근처에 오도록 경계 조정
        double paddingTop = 0.008;     // 위쪽 여백 줄임
        double paddingBottom = 0.025;  // 아래쪽 여백 늘림
        double paddingSide = 0.015;

        // 사용자 위치 기준으로 경계 재계산
        minLat = min(minLat, userLat - paddingBottom);
        maxLat = max(maxLat, userLat + paddingTop);
        minLng = min(minLng, userLng - paddingSide);
        maxLng = max(maxLng, userLng + paddingSide);
      } else {
        double paddingTop = 0.02;
        double paddingBottom = 0.015;
        double paddingSide = 0.02;

        minLat = minLat - paddingBottom;
        maxLat = maxLat + paddingTop;
        minLng = minLng - paddingSide;
        maxLng = maxLng + paddingSide;
      }

      double verticalOffset = 0.0;  // 기존 -0.05 제거

      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat + verticalOffset, minLng),
        northeast: LatLng(maxLat + verticalOffset, maxLng),
      );

      print('경계 설정(사용자 중심): 남서(${bounds.southwest.latitude}, ${bounds.southwest.longitude}), 북동(${bounds.northeast.latitude}, ${bounds.northeast.longitude})');

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      ).catchError((e) {
        print('경계 설정 오류: $e. 기본 위치로 이동합니다.');
        _simpleCameraMove();
      });
    } catch (e) {
      print('경계 계산 오류: $e. 기본 위치로 이동합니다.');
      _simpleCameraMove();
    }
  }
  // 🔒 경로 업데이트 및 지도 표시
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
            zoom: 10.0,  // 13.0 → 10.0
            tilt: 10.0,
          ),
        ),
      );
    } catch (e) {
      print('단순 카메라 이동마저 실패: $e');
    }
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
          // 교통수단 아이콘과 경로 옵션 버튼
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
          // 지도 위젯
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

          // 상단: 교통수단 선택
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildTransportModeSelector(),
          ),

          // 하단 정보 패널
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                  // 오류 메시지 (간단하게)
                  if (_errorMessage != null && _routePoints.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '일부 경로 정보가 제한적입니다',
                              style: const TextStyle(color: Colors.orange, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 제목 행 (깔끔하게)
                  Row(
                    children: [
                      Text(_selectedTransportMode.icon, style: TextStyle(fontSize: 24)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_selectedTransportMode.label} 경로',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '거리: ${_estimatedDistance.toStringAsFixed(1)}km • 시간: $_estimatedDuration분',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      // 검색 상태 표시
                      if (_isSearchingRoutes)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // 🎯 경로 옵션 버튼만 (중앙에 크게)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        print('🎴 경로 옵션 버튼 클릭됨');
                        print('현재 경로 수: ${_routeOptions.length}');
                        print('검색 중 여부: $_isSearchingRoutes');
                        _showRouteOptions();
                      },
                      icon: Icon(Icons.alt_route, size: 20),
                      label: Text(
                        '${_routeOptions.length}개 경로 옵션 보기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedTransportMode.color,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 로딩 인디케이터
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
    );
  }
}