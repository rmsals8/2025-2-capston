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
// 대중교통 정보를 저장할 클래스
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
  // 카메라 이동 관련 변수 개선
  bool _mapInitialized = false;
  bool _isRouteInitialized = false;
  bool _showFullInstructions = false;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<String> _instructions = [];
  List<TransitDetails> _transitDetails = []; // 대중교통 세부 정보
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  String get apiKey => dotenv.dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  bool _isLoading = true;
  String? _errorMessage;
  String _transportMode = ''; // 추가된 변수

  // 경로 정보
  List<LatLng> _routePoints = [];
  String _routeSummary = '';
  int _estimatedDuration = 0;
  double _estimatedDistance = 0;

  // 보정된 좌표 저장
  late double _correctedStartLat;
  late double _correctedStartLon;
  late double _correctedEndLat;
  late double _correctedEndLon;

  @override
  void initState() {
    super.initState();
    _transportMode = widget.transportMode; // 초기화

    // 좌표 보정 - 개선된 로직 적용
    _correctCoordinates();

    // 화면 구성 후 초기화 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMap();
    });
  }

  @override
  void dispose() {
    // 구독 해제
    _positionStreamSubscription?.cancel();

    // 컨트롤러 안전하게 해제
    if (_mapController != null) {
      _mapController = null;
    }

    super.dispose();
  }

  // 1. 좌표 보정 로직 전면 개선
  void _correctCoordinates() {
    // 원본 좌표 저장 및 로깅
    final double origStartLat = widget.startLat;
    final double origStartLon = widget.startLon;
    final double origEndLat = widget.endLat;
    final double origEndLon = widget.endLon;

    print('원본 좌표: 출발($origStartLat, $origStartLon), 도착($origEndLat, $origEndLon)');

    // 1단계: 좌표 범위 확인
    // 한국 위도: 33~39도, 경도: 124~132도
    bool startInKoreaRange = _isInKoreanRange(origStartLat, origStartLon);
    bool endInKoreaRange = _isInKoreanRange(origEndLat, origEndLon);

    // 2단계: 위도/경도 스왑 필요 여부 확인
    bool needSwap = _needCoordinateSwap(origStartLat, origStartLon) ||
        _needCoordinateSwap(origEndLat, origEndLon);

    print('좌표 상태: 한국 범위(출발: $startInKoreaRange, 도착: $endInKoreaRange), 스왑 필요: $needSwap');

    // 임시 좌표 변수 초기화
    double tempStartLat = origStartLat;
    double tempStartLon = origStartLon;
    double tempEndLat = origEndLat;
    double tempEndLon = origEndLon;

    // 3단계: 필요한 경우 스왑 적용
    if (needSwap) {
      double temp = tempStartLat;
      tempStartLat = tempStartLon;
      tempStartLon = temp;

      temp = tempEndLat;
      tempEndLat = tempEndLon;
      tempEndLon = temp;

      print('스왑 후 좌표: 출발($tempStartLat, $tempStartLon), 도착($tempEndLat, $tempEndLon)');
    }

    // 4단계: 정규화 적용 - 원단위 미만 정규화 -> 도단위 변환
    _correctedStartLat = _normalizeCoordinate(tempStartLat, true);
    _correctedStartLon = _normalizeCoordinate(tempStartLon, false);
    _correctedEndLat = _normalizeCoordinate(tempEndLat, true);
    _correctedEndLon = _normalizeCoordinate(tempEndLon, false);

    // 5단계: 최종 좌표가 유효한지 확인
    bool isStartValid = _isValidKoreanCoordinate(_correctedStartLat, _correctedStartLon);
    bool isEndValid = _isValidKoreanCoordinate(_correctedEndLat, _correctedEndLon);

    print('정규화 후 최종 좌표:');
    print('출발: $_correctedStartLat, $_correctedStartLon (유효: $isStartValid)');
    print('도착: $_correctedEndLat, $_correctedEndLon (유효: $isEndValid)');

    // 6단계: 여전히 유효하지 않다면 기본 좌표 사용 (울산 지역)
    if (!isStartValid || !isEndValid) {
      print('경고: 유효하지 않은 좌표 감지. 기본 울산 좌표로 설정합니다.');

      if (!isStartValid) {
        _correctedStartLat = 35.5384; // 울산대학교 위도
        _correctedStartLon = 129.2582; // 울산대학교 경도
      }

      if (!isEndValid) {
        _correctedEndLat = 35.5361; // 울산시청 위도
        _correctedEndLon = 129.3114; // 울산시청 경도
      }

      print('기본 좌표로 대체: 출발($_correctedStartLat, $_correctedStartLon), 도착($_correctedEndLat, $_correctedEndLon)');
    }
  }

  // 한국 좌표 범위 확인 (개선된 함수)
  bool _isInKoreanRange(double lat, double lon) {
    return (lat >= 33.0 && lat <= 39.0 && lon >= 124.0 && lon <= 132.0);
  }

  // 좌표가 스왑이 필요한지 확인
  bool _needCoordinateSwap(double lat, double lon) {
    // 위도가 경도 범위에 있거나, 경도가 위도 범위에 있는 경우
    return (lat > 100 || (lon > 33.0 && lon < 39.0));
  }

  // 한국 영역 좌표 유효성 검사 함수 (기존 함수 재사용)
  bool _isValidKoreanCoordinate(double lat, double lon) {
    return lat >= 33.0 && lat <= 39.0 && lon >= 124.0 && lon <= 132.0;
  }

  // 좌표 정규화 함수 개선
  double _normalizeCoordinate(double value, bool isLatitude) {
    // 이미 정상 범위 내에 있는 경우 그대로 반환
    if (isLatitude && value >= -90 && value <= 90) return value;
    if (!isLatitude && value >= -180 && value <= 180) return value;

    // 큰 값 처리 - 10^n 단위로 저장된 경우 (E6, E7 등)
    if (value > 1000) {
      int digits = value.toInt().toString().length;

      if (digits >= 8) {
        return value / 10000000.0; // E7 형식
      } else if (digits >= 6) {
        return value / 1000000.0;  // E6 형식
      } else if (digits >= 5) {
        return value / 100000.0;   // E5 형식
      }
    }

    // 값이 여전히 유효하지 않으면 울산의 기본 좌표 반환
    return isLatitude ? 35.5384 : 129.2582; // 울산대학교 좌표
  }

  // 2. 지도 초기화 로직 개선
  Future<void> _initMap() async {
    // 위치 권한 확인 및 요청
    bool hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      setState(() {
        _errorMessage = '위치 권한이 없습니다.';
        _isLoading = false;
      });
      return;
    }

    try {
      // 현재 위치 가져오기
      _currentPosition = await Geolocator.getCurrentPosition();

      // 위치 추적 시작
      _startLocationTracking();

      // 경로 API 호출
      if (!_isRouteInitialized) {
        await _fetchRoute();
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

  // 위치 권한 확인 함수
  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // 3. 카메라 이동 로직 전면 개선 - 지도를 남쪽으로 조정
  void _moveMapCamera() {
    if (_mapController == null || !mounted) return;

    try {
      // 중앙점 계산
      final centerLat = (_correctedStartLat + _correctedEndLat) / 2;
      final centerLon = (_correctedStartLon + _correctedEndLon) / 2;

      // 지도를 남쪽으로 이동시켜 경로가 화면 위쪽에 위치하도록 조정
      // 위도 값을 증가시켜 지도를 남쪽으로 이동
      final adjustedCenterLat = centerLat + 10; // 양수 값으로 남쪽 방향 조정

      // 거리 계산하여 적절한 줌 레벨 결정
      final distance = _calculateDistance(
          _correctedStartLat, _correctedStartLon,
          _correctedEndLat, _correctedEndLon
      );

      // 거리에 따른 최적 줌 레벨 - 더 세밀하게 조정
      double zoomLevel;
      if (distance < 1) zoomLevel = 16.0;      // 1km 미만
      else if (distance < 3) zoomLevel = 15.0; // 1-3km
      else if (distance < 7) zoomLevel = 14.0; // 3-7km
      else if (distance < 15) zoomLevel = 13.0; // 7-15km
      else if (distance < 30) zoomLevel = 12.0; // 15-30km
      else if (distance < 70) zoomLevel = 11.0; // 30-70km
      else zoomLevel = 10.0;                    // 70km 이상

      print('지도 이동(남쪽 조정): 중심점($adjustedCenterLat, $centerLon), 거리(${distance.toStringAsFixed(2)}km), 줌($zoomLevel)');

      // 애니메이션 없이 이동 (더 안정적)
      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(adjustedCenterLat, centerLon),
            zoom: zoomLevel,
            tilt: 10.0, // 약간의 3D 기울기 추가 - 더 나은 시각적 효과
          ),
        ),
      );

      // 약간의 지연 후 경로에 맞게 경계 조정
      Future.delayed(Duration(milliseconds: 500), () {
        if (_mapController != null && mounted) {
          _fitMapToBounds();
        }
      });
    } catch (e) {
      print('카메라 이동 오류: $e');
    }
  }

  // 4. 지도 경계 맞추기 로직 개선 - 지도를 아래쪽으로 조금 이동
  void _fitMapToBounds() {
    if (_mapController == null || !mounted) return;

    try {
      List<LatLng> boundPoints = [];

      // 경로 포인트가 있는 경우 이를 사용
      if (_routePoints.isNotEmpty) {
        boundPoints.addAll(_routePoints);
      } else {
        // 출발지와 도착지 포인트만 사용
        boundPoints.add(LatLng(_correctedStartLat, _correctedStartLon));
        boundPoints.add(LatLng(_correctedEndLat, _correctedEndLon));
      }

      // 최소/최대 좌표 찾기
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

      // 경계가 너무 작을 경우 최소 크기 보장
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

      // 여백 추가 - 아래쪽에 더 많은 여백 추가 (화면의 상단에 경로 배치)
      double paddingTop = 0.008;     // 위쪽 여백 더 크게
      double paddingBottom = 0.002;  // 아래쪽 여백 작게
      double paddingSide = 0.005;    // 좌우 여백

      // 중심점을 약간 아래로 조정 (지도를 위로 올리는 효과)
      double verticalOffset = -0.05; // 음수 값으로 지도를 위로 조정

      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat - paddingBottom + verticalOffset, minLng - paddingSide),
        northeast: LatLng(maxLat + paddingTop + verticalOffset, maxLng + paddingSide),
      );

      print('경계 설정(아래로 조정): 남서(${bounds.southwest.latitude}, ${bounds.southwest.longitude}), 북동(${bounds.northeast.latitude}, ${bounds.northeast.longitude})');

      // 실패 가능성 대비한 안전한 API 호출
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

  // 5. 오류 발생 시 간단한 카메라 이동 백업 전략 - 남쪽으로 조정
  void _simpleCameraMove() {
    if (_mapController == null || !mounted) return;

    try {
      // 중심점 계산 - 출발지와 도착지의 중간
      final centerLat = (_correctedStartLat + _correctedEndLat) / 2;
      final centerLon = (_correctedStartLon + _correctedEndLon) / 2;

      // 지도를 남쪽으로 이동하기 위해 중심점을 위로 조정
      // 위도를 약간 증가시켜 지도를 남쪽으로 이동 (경로는 상대적으로 위로 이동)
      final adjustedCenterLat = centerLat + 0.005;

      print('단순 카메라 이동(남쪽 조정): 중심점($adjustedCenterLat, $centerLon)');

      // 애니메이션 없이 이동 (최대한 안정적으로)
      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(adjustedCenterLat, centerLon),
            zoom: 13.0, // 적당한 기본 확대 수준
            tilt: 10.0, // 약간의 기울기 추가 - 더 좋은 시각적 효과
          ),
        ),
      );
    } catch (e) {
      print('단순 카메라 이동마저 실패: $e');
    }
  }

  // 6. 현재 위치 추적 함수
  void _startLocationTracking() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10m마다 업데이트
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
        _updateCurrentLocationMarker();
      });

      // 현재 위치 변경 시 마커만 업데이트하고 지도는 이동하지 않음
      // (네비게이션 모드에서는 사용자가 지도를 직접 조작할 수 있게)
    });
  }

  // 7. 현재 위치 마커 업데이트
  void _updateCurrentLocationMarker() {
    if (_currentPosition == null) return;

    // 기존 현재 위치 마커 제거
    _markers.removeWhere((marker) => marker.markerId.value == 'current');

    // 새 현재 위치 마커 추가
    _markers.add(
      Marker(
        markerId: const MarkerId('current'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: '현재 위치'),
      ),
    );
  }

  // 8. 경로 데이터 가져오기 함수 개선
  Future<void> _fetchRoute([String? transportMode]) async {
    if (_isRouteInitialized && transportMode == null) return;

    try {
      // const apiKey = 'AIzaSyA036NtD7ALG40jOnqSGks2QsI1nAG9cGI';

      // 이동 수단 설정
      if (transportMode != null) {
        _transportMode = transportMode;
      }

      String mode;
      if (_transportMode == 'DRIVING') {
        mode = 'driving';
      } else if (_transportMode == 'TRANSIT') {
        mode = 'transit';
      } else {
        mode = 'walking';
      }

      // 좌표 유효성 최종 확인
      if (!_isValidKoreanCoordinate(_correctedStartLat, _correctedStartLon) ||
          !_isValidKoreanCoordinate(_correctedEndLat, _correctedEndLon)) {
        print('경고: API 호출 전 좌표 유효성 검사 실패, 기본 좌표 사용');

        // 울산 지역 기본 좌표
        _correctedStartLat = 35.5384; // 울산대학교 위도
        _correctedStartLon = 129.2582; // 울산대학교 경도
        _correctedEndLat = 35.5361; // 울산시청 위도
        _correctedEndLon = 129.3114; // 울산시청 경도
      }

      // API 요청 URL 구성
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
        // UTF-8 디코딩
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('API 응답 상태: ${data['status']}');

        if (data['status'] == 'OK') {
          // 경로 디코딩
          PolylinePoints polylinePoints = PolylinePoints();
          List<PointLatLng> decodedPolyline =
          polylinePoints.decodePolyline(data['routes'][0]['overview_polyline']['points']);

          setState(() {
            _routePoints = decodedPolyline
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();

            // 요약 정보 추출
            _routeSummary = data['routes'][0]['summary'] ?? '경로 정보';
            _estimatedDuration = data['routes'][0]['legs'][0]['duration']['value'] ~/ 60;
            _estimatedDistance = data['routes'][0]['legs'][0]['distance']['value'] / 1000;

            // 상세 안내 메시지 추출
            _instructions = [];
            _transitDetails = []; // 대중교통 정보 초기화

            for (var step in data['routes'][0]['legs'][0]['steps']) {
              String instruction = step['html_instructions'] ?? '';
              instruction = instruction.replaceAll(RegExp(r'<[^>]*>'), ' ');
              _instructions.add(instruction);

              // 대중교통 정보 추출
              if (step['travel_mode'] == 'TRANSIT' && step['transit_details'] != null) {
                final transitDetails = step['transit_details'];
                final line = transitDetails['line']?['short_name'] ??
                    transitDetails['line']?['name'] ?? '노선 정보 없음';
                final vehicle = transitDetails['line']?['vehicle']?['name'] ?? '대중교통';
                final departureStop = transitDetails['departure_stop']?['name'] ?? '출발지';
                final arrivalStop = transitDetails['arrival_stop']?['name'] ?? '도착지';
                final numStops = transitDetails['num_stops'] ?? 0;
                final headSign = transitDetails['headsign'] ?? '';

                // 대중교통 안내 추가
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

          // 지도에 경로 표시
          _updateMapWithRoute();
        } else {
          print('API 오류: ${data['error_message'] ?? '상세 정보 없음'}');

          // 직선 경로 생성
          _createDirectRoute();

          setState(() {
            if (data['status'] == 'ZERO_RESULTS') {
              _errorMessage = '해당 이동 수단으로 경로를 찾을 수 없습니다. 직선 경로를 표시합니다.';
            } else {
              _errorMessage = '경로 탐색 실패: ${data['status']}. 직선 경로를 표시합니다.';
            }
          });
        }
      } else {
        // API 호출 실패 시 직선 경로
        _createDirectRoute();

        setState(() {
          _errorMessage = '경로 API 호출 실패: ${response.statusCode}. 직선 경로를 표시합니다.';
        });
      }
    } catch (e) {
      print('경로 가져오기 예외: $e');

      // 예외 발생 시 직선 경로
      _createDirectRoute();

      setState(() {
        _errorMessage = '경로 가져오기 오류: $e. 직선 경로를 표시합니다.';
      });
    }
  }

  // 9. 직선 경로 생성 함수
  void _createDirectRoute() {
    print('직선 경로 생성');

    // 출발지와 도착지 간 직선 경로
    _routePoints = [
      LatLng(_correctedStartLat, _correctedStartLon),
      LatLng(_correctedEndLat, _correctedEndLon),
    ];

    // 직선 거리 계산
    double distance = _calculateDistance(
        _correctedStartLat, _correctedStartLon,
        _correctedEndLat, _correctedEndLon
    );

    // 이동 수단별 예상 시간 계산
    int durationMinutes;
    if (_transportMode == 'WALK') {
      durationMinutes = (distance * 12).round(); // 도보는 km당 약 12분
    } else if (_transportMode == 'TRANSIT') {
      durationMinutes = (distance * 3).round(); // 대중교통은 km당 약 3분
    } else {
      durationMinutes = (distance * 1.5).round(); // 자동차는 km당 약 1.5분
    }

    _routeSummary = '${widget.startName}에서 ${widget.endName}까지 직선 경로';
    _estimatedDuration = durationMinutes;
    _estimatedDistance = distance;

    // 기본 안내 메시지
    _instructions = ['${widget.startName}에서 ${widget.endName}까지 이동합니다.'];

    // 지도에 경로 표시
    _updateMapWithRoute();
  }

  // 10. 경로 업데이트 및 지도 표시 함수 개선
  void _updateMapWithRoute() {
    // 경로 정보 로깅
    print('경로 업데이트: ${_routePoints.length}개 포인트');
    if (_routePoints.isNotEmpty) {
      print('첫 포인트: ${_routePoints.first.latitude}, ${_routePoints.first.longitude}');
      print('마지막 포인트: ${_routePoints.last.latitude}, ${_routePoints.last.longitude}');
    }

    // 마커 초기화
    _markers.clear();

    // 출발지, 도착지 마커 추가
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

    // 현재 위치 마커 추가
    _updateCurrentLocationMarker();

    // 폴리라인 초기화
    _polylines.clear();

    // 경로 폴리라인 추가
    if (_routePoints.isNotEmpty) {
      Color routeColor;
      switch (_transportMode) {
        case 'WALK':
          routeColor = Colors.green;
          break;
        case 'TRANSIT':
          routeColor = Colors.blue;
          break;
        case 'DRIVING':
          routeColor = Colors.red;
          break;
        default:
          routeColor = Colors.purple;
      }

      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: routeColor,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );

      // 경로 하이라이트 효과 추가
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_highlight'),
          points: _routePoints,
          color: routeColor.withOpacity(0.3),
          width: 8, // 더 넓게
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

    // UI 업데이트
    setState(() {});

    // 지연 후 지도 경계 맞추기
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted && _mapController != null) {
        print('경로에 맞춰 지도 경계 조정...');
        _fitMapToBounds();
      }
    });
  }

  // 경로 방향에 맞는 베어링 계산
  double _calculateBearing(double startLat, double startLng, double endLat, double endLng) {
    startLat = _toRadians(startLat);
    startLng = _toRadians(startLng);
    endLat = _toRadians(endLat);
    endLng = _toRadians(endLng);

    double y = sin(endLng - startLng) * cos(endLat);
    double x = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(endLng - startLng);
    double bearing = atan2(y, x);

    // 라디안에서 도(degree)로 변환하고 0-360 범위로 조정
    bearing = _toDegrees(bearing);
    bearing = (bearing + 360) % 360;

    return bearing;
  }

  // 라디안/도 변환 함수
  double _toRadians(double degree) {
    return degree * (pi / 180);
  }

  double _toDegrees(double radian) {
    return radian * (180 / pi);
  }

  // 두 지점 간 거리 계산 (하버사인 공식)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // 지구 반지름 (km)
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c; // 킬로미터 단위 거리
  }

  // 이동 수단 변경 함수
  void _changeTransportMode(String newMode) async {
    if (_transportMode == newMode) return;

    // 화면 상태 초기화
    setState(() {
      _isLoading = true;
      _routePoints = [];
      _instructions = [];
      _markers.clear();
      _polylines.clear();
      _transitDetails = [];
      _transportMode = newMode;
    });

    // 새 경로 로드
    try {
      await _fetchRoute(newMode);
    } catch (e) {
      setState(() {
        _errorMessage = '경로 가져오기 오류: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 이동 수단 텍스트 변환
  String _getTransportModeText() {
    switch (_transportMode) {
      case 'WALK':
        return '도보';
      case 'TRANSIT':
        return '대중교통';
      case 'DRIVING':
        return '자동차';
      default:
        return '이동';
    }
  }

  // 경로 안내 UI 위젯
  Widget _buildRouteInstructions() {
    // 안내가 없을 경우 빈 컨테이너 반환
    if (_instructions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: const Text('경로 안내 정보가 없습니다.'),
      );
    }

    // 대중교통 요약 정보 위젯
    Widget _buildTransitSummary() {
      if (_transitDetails.isEmpty || _transportMode != 'TRANSIT') {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '대중교통 이용 정보',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${detail.vehicle} ${detail.line}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: vehicleColor,
                            ),
                          ),
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

    // 안내 목록 표시
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '상세 안내',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(_showFullInstructions ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _showFullInstructions = !_showFullInstructions;
                    });
                  },
                ),
              ],
            ),
          ),

          // 대중교통 요약 정보 표시
          if (_transitDetails.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTransitSummary(),
            ),

          const Divider(height: 1),
          if (_showFullInstructions)
          // 전체 안내 목록
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _instructions.length,
              itemBuilder: (context, index) {
                // HTML 태그 제거
                String instruction = _instructions[index].replaceAll(RegExp(r'<[^>]*>'), ' ').trim();

                // 대중교통 관련 안내인지 확인
                bool isTransitInfo = instruction.startsWith('🚍');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: isTransitInfo
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        radius: 12,
                        child: isTransitInfo
                            ? const Icon(Icons.directions_transit, size: 14, color: Colors.blue)
                            : Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          instruction,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isTransitInfo ? FontWeight.bold : FontWeight.normal,
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
          // 첫 번째 안내만 표시
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  // 이동 수단 버튼 위젯
  Widget _buildTransportModeButton(String mode, IconData icon, String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.blue : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.startName} → ${widget.endName}'),
      ),
      body: Stack(
        children: [
          // 지도 위젯
          GoogleMap(
            initialCameraPosition: CameraPosition(
              // 특정 위치 대신 한국의 중심을 초기 위치로 사용 (지도 로드 시)
              target: LatLng(
                35.907757, // 한국 중부권 위도
                127.766922, // 한국 중부권 경도
              ),
              zoom: 7.0, // 한국 전체가 보이는 줌 레벨
              tilt: 10.0, // 약간의 기울기 추가
            ),
            onMapCreated: (GoogleMapController controller) {
              print('지도 컨트롤러 생성됨');
              _mapController = controller;

              // 지도가 로드된 후 위치 설정 (약간의 지연 추가)
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

          // 하단 정보 패널
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 안내 목록 패널
                if (_instructions.isNotEmpty && !_isLoading) _buildRouteInstructions(),

                // 경로 정보 및 컨트롤 패널
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: _instructions.isEmpty
                        ? const BorderRadius.vertical(top: Radius.circular(16))
                        : BorderRadius.zero,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null && _routePoints.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
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

                      Text(
                        '${_getTransportModeText()} 경로',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '총 거리: ${_estimatedDistance.toStringAsFixed(1)}km • 예상 시간: $_estimatedDuration분',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 이동 수단 선택 UI
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTransportModeButton(
                            'WALK',
                            Icons.directions_walk,
                            '도보',
                            _transportMode == 'WALK',
                                () => _changeTransportMode('WALK'),
                          ),
                          _buildTransportModeButton(
                            'TRANSIT',
                            Icons.directions_bus,
                            '대중교통',
                            _transportMode == 'TRANSIT',
                                () => _changeTransportMode('TRANSIT'),
                          ),
                          _buildTransportModeButton(
                            'DRIVING',
                            Icons.directions_car,
                            '자동차',
                            _transportMode == 'DRIVING',
                                () => _changeTransportMode('DRIVING'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_mapController != null) {
                              _fitMapToBounds();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('전체 경로 보기'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 로딩 인디케이터
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }}