// lib/screens/navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' show pi, sin, cos, sqrt, atan2;
import '../../services/location_service.dart';
import '../../services/google_transit_service.dart';
import '../../models/route_info.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
class NavigationScreen extends StatefulWidget {
  // 🔧 수정된 생성자 - RouteSelectionBottomSheet와 호환
  final RouteInfo route;
  final LatLng origin;
  final LatLng destination;
  final String transportMode;
  final GoogleTransitRoute? transitRoute;

  const NavigationScreen({
    Key? key,
    required this.route,
    required this.origin,
    required this.destination,
    this.transportMode = 'driving',
    this.transitRoute,
  }) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  List<LatLng> _currentRoutePoints = [];
  final LocationService _locationService = LocationService();
  String get apiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  Timer? _locationTimer;
  int _currentStepIndex = 0;
  bool _isNavigating = false;
  RouteInfo? _currentRoute;  // late 제거하고 nullable로 변경
  List<TransitStep> _transitSteps = [];
  GoogleTransitRoute? _detailedTransitRoute;

  @override
  void initState() {
    super.initState();
    print('🎯 NavigationScreen initState - 전달받은 origin: ${widget.origin?.latitude}, ${widget.origin?.longitude}'); // 🆕 디버그
    print('🎯 NavigationScreen initState - 전달받은 destination: ${widget.destination.latitude}, ${widget.destination.longitude}'); // 🆕 디버그
    // 🆕 초기 경로 포인트 설정
    _currentRoutePoints = List.from(widget.route.points);
    // 🆕 전달받은 origin을 먼저 현재 위치로 설정
    if (widget.origin != null) {
      _currentLocation = widget.origin;
      print('🎯 초기 현재 위치 설정: ${widget.origin!.latitude}, ${widget.origin!.longitude}');
    }
    _loadTransitData();
    _startNavigation();
    _getCurrentLocationAndStart();
  }
  Future<void> _getCurrentLocationAndStart() async {
    try {
      final position = await _locationService.getCurrentLocation();
      final currentLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = currentLocation;
      });

      print('현재 위치에서 네비게이션 시작: ${currentLocation.latitude}, ${currentLocation.longitude}');

      // 현재 위치에서 목적지까지 새로운 경로 요청
      await _recalculateRouteFromCurrentLocation(currentLocation);

    } catch (e) {
      print('현재 위치 획득 실패, 기본 출발점 사용: $e');
      setState(() {
        _currentLocation = widget.origin;
      });
    } finally {
      _startNavigation();
    }
  }
  Future<void> _recalculateRouteFromCurrentLocation(LatLng currentLocation) async {
    try {
      print('🔍 현재 위치에서 목적지까지 경로 재계산 시작...');

      // Google Directions API 모드 설정
      String mode;
      switch (widget.transportMode.toLowerCase()) {
        case 'walking':
        case 'walk':
          mode = 'walking';
          break;
        case 'transit':
        case 'publictransport':
          mode = 'transit';
          break;
        case 'driving':
        case 'car':
        default:
          mode = 'driving';
          break;
      }

      // API 요청 URL 구성
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?'
              'origin=${currentLocation.latitude.toStringAsFixed(6)},${currentLocation.longitude.toStringAsFixed(6)}'
              '&destination=${widget.destination.latitude.toStringAsFixed(6)},${widget.destination.longitude.toStringAsFixed(6)}'
              '&mode=$mode'
              '&language=ko'
              '&key=$apiKey'
      );

      print('📡 API 요청: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          // 새로운 경로 포인트 파싱
          PolylinePoints polylinePoints = PolylinePoints();
          List<PointLatLng> decodedPolyline = polylinePoints.decodePolyline(
              data['routes'][0]['overview_polyline']['points']
          );

          List<LatLng> newRoutePoints = decodedPolyline
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          // 거리와 시간 정보 추출
          final leg = data['routes'][0]['legs'][0];
          final newDistance = leg['distance']['text'];
          final newDuration = leg['duration']['text'];

          setState(() {
            _currentRoute = widget.route.copyWith(
              points: newRoutePoints,
              distance: newDistance,
              duration: newDuration,
            );
          });

          print('✅ 경로 재계산 완료: $newDistance, $newDuration');
          print('📍 새로운 경로 포인트 ${newRoutePoints.length}개 생성');

        } else {
          print('❌ Google API 응답 오류: ${data['status']}');
        }
      } else {
        print('❌ HTTP 요청 실패: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ 경로 재계산 실패: $e');
    }
  }
  Future<void> _loadTransitData() async {
    if (_isTransitMode) {
      if (widget.transitRoute != null) {
        _detailedTransitRoute = widget.transitRoute;
        _transitSteps = widget.transitRoute!.steps;
        print('✅ 대중교통 단계 ${_transitSteps.length}개 로드 완료');

        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  bool get _isTransitMode =>
      widget.transportMode.toLowerCase() == 'transit' ||
          widget.transportMode.toLowerCase() == 'publictransport';

  void _startNavigation() {
    // 전달받은 origin을 현재 위치로 우선 설정
    if (widget.origin != null && _currentLocation == null) {
      _currentLocation = widget.origin;
      print('🎯 네비게이션 시작 - 현재 위치 설정: ${widget.origin!.latitude}, ${widget.origin!.longitude}');
    }

    setState(() {
      _isNavigating = true;
    });

    // 🆕 즉시 경로 재계산
    _recalculateRoute();

    _locationTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _updateCurrentLocation(),
    );
  }

  void _pauseNavigation() {
    setState(() {
      _isNavigating = false;
    });
    _locationTimer?.cancel();
  }

  void _resumeNavigation() {
    _startNavigation();
  }

  Future<void> _updateCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (!mounted) return;

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      // 🆕 현재 위치가 변경되면 경로를 다시 계산
      if (_isNavigating && _currentLocation != null) {
        await _recalculateRoute();
        _updateCamera();
        _checkArrival();
      }
    } catch (e) {
      print('위치 업데이트 실패: $e');

      // 위치 서비스 실패 시 전달받은 origin 사용
      if (widget.origin != null && _currentLocation == null) {
        setState(() {
          _currentLocation = widget.origin;
        });
        print('🎯 전달받은 origin을 현재 위치로 설정: ${widget.origin!.latitude}, ${widget.origin!.longitude}');

        // 🆕 초기 경로 계산
        if (_isNavigating) {
          await _recalculateRoute();
        }
      }
    }
  }
  Future<void> _recalculateRoute() async {
    if (_currentLocation == null) return;

    try {
      print('🔍 카카오 API로 현재 위치에서 목적지까지 경로 재계산 시작...');

      final kakaoApiKey = dotenv.env['KAKAO_API_KEY'];
      if (kakaoApiKey == null || kakaoApiKey.isEmpty) {
        throw Exception('Kakao API 키 없음');
      }

      // 교통수단별 카카오 API URL 결정
      String apiUrl;
      Map<String, dynamic> requestBody;

      if (widget.transportMode.toLowerCase() == 'walking') {
        // 🚶‍♂️ 도보 경로
        apiUrl = 'https://apis-navi.kakaomobility.com/v1/waypoints/directions';
        requestBody = {
          'origin': {
            'x': _currentLocation!.longitude,
            'y': _currentLocation!.latitude
          },
          'destination': {
            'x': widget.destination.longitude,
            'y': widget.destination.latitude
          },
          'waypoints': [],
          'priority': 'RECOMMEND',
          'alternatives': false
        };
      } else {
        // 🚗 자동차 경로
        apiUrl = 'https://apis-navi.kakaomobility.com/v1/directions';
        requestBody = {
          'origin': {
            'x': _currentLocation!.longitude,
            'y': _currentLocation!.latitude
          },
          'destination': {
            'x': widget.destination.longitude,
            'y': widget.destination.latitude
          },
          'waypoints': [],
          'priority': 'RECOMMEND',
          'car_fuel': 'GASOLINE',
          'car_hipass': false,
          'alternatives': false,
          'road_details': false
        };
      }

      print('📡 카카오 API 요청: $apiUrl');
      print('📋 요청 데이터: $requestBody');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'KakaoAK $kakaoApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('📡 카카오 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final sections = route['sections'] as List? ?? [];

          List<LatLng> newRoutePoints = [];

          // 카카오 API 응답에서 좌표 추출
          for (var section in sections) {
            if (section['roads'] != null) {
              for (var road in section['roads']) {
                if (road['vertexes'] != null) {
                  final vertexes = road['vertexes'] as List;
                  for (int j = 0; j < vertexes.length; j += 2) {
                    if (j + 1 < vertexes.length) {
                      newRoutePoints.add(LatLng(
                        vertexes[j + 1].toDouble(),
                        vertexes[j].toDouble(),
                      ));
                    }
                  }
                }
              }
            }
          }

          if (newRoutePoints.isNotEmpty && mounted) {
            setState(() {
              _currentRoutePoints = newRoutePoints;
            });
            print('✅ 카카오 경로 재계산 완료 - ${newRoutePoints.length}개 포인트');
          } else {
            // 포인트가 없으면 직선 경로
            if (mounted) {
              setState(() {
                _currentRoutePoints = [_currentLocation!, widget.destination];
              });
              print('🔧 카카오 응답에 포인트 없음, 직선 경로 사용');
            }
          }
        } else {
          print('❌ 카카오 경로 계산 실패: 응답에 routes 없음');
          // 직선 경로 폴백
          if (mounted) {
            setState(() {
              _currentRoutePoints = [_currentLocation!, widget.destination];
            });
            print('🔧 카카오 실패로 직선 경로 사용');
          }
        }
      } else {
        print('❌ 카카오 API 호출 실패: ${response.statusCode}');
        print('❌ 응답 내용: ${response.body}');

        // 직선 경로 폴백
        if (mounted) {
          setState(() {
            _currentRoutePoints = [_currentLocation!, widget.destination];
          });
          print('🔧 카카오 API 실패로 직선 경로 사용');
        }
      }
    } catch (e) {
      print('❌ 카카오 경로 재계산 오류: $e');

      // 예외 발생 시 직선 경로
      if (mounted) {
        setState(() {
          _currentRoutePoints = [_currentLocation!, widget.destination];
        });
        print('🔧 예외 발생으로 직선 경로 사용');
      }
    }
  }

  void _updateCamera() {
    if (_currentLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation!,
            zoom: _isTransitMode ? 13 : 14,  // 14→13, 17→14 (줌 아웃)
            tilt: _isTransitMode ? 0 : 30,   // 45→30 (틸트 줄임)
          ),
        ),
      );
    }
  }

  void _checkArrival() {
    if (_currentLocation == null) return;

    if (_calculateDistance(_currentLocation!, widget.destination) < 100) {
      _showArrivalDialog();
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000;
    final lat1 = p1.latitude * (pi / 180);
    final lat2 = p2.latitude * (pi / 180);
    final dLat = (p2.latitude - p1.latitude) * (pi / 180);
    final dLng = (p2.longitude - p1.longitude) * (pi / 180);

    final a = sin(dLat/2) * sin(dLat/2) +
        cos(lat1) * cos(lat2) *
            sin(dLng/2) * sin(dLng/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));

    return earthRadius * c;
  }

  String _getTransportModeIcon() {
    if (_transitSteps.isNotEmpty && _currentStepIndex < _transitSteps.length) {
      final currentStep = _transitSteps[_currentStepIndex];

      switch (currentStep.mode) {
        case 'WALKING':
          return '🚶‍♂️';
        case 'TRANSIT':
          switch (currentStep.transitType?.toLowerCase()) {
            case 'subway':
              return '🚇';
            case 'bus':
              return '🚌';
            default:
              return '🚌';
          }
        default:
          return '🚌';
      }
    }

    return _isTransitMode ? '🚌' : '🚗';
  }

  Color _getRouteColor() {
    switch (widget.transportMode.toLowerCase()) {
      case 'walking':
      case 'pedestrian':
        return Colors.green;
      case 'driving':
      case 'car':
        return Colors.blue;
      case 'transit':
      case 'publictransport':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Color _getStepColor(int stepIndex, TransitStep step) {
    if (step.mode == 'WALKING') {
      return Colors.green;
    } else if (step.mode == 'TRANSIT') {
      switch (step.transitType?.toLowerCase()) {
        case 'subway':
          if (step.transitLine?.contains('1호선') == true) return Color(0xFF0052A4);
          if (step.transitLine?.contains('2호선') == true) return Color(0xFF00A84D);
          if (step.transitLine?.contains('3호선') == true) return Color(0xFFEF7C1C);
          if (step.transitLine?.contains('4호선') == true) return Color(0xFF00A5DE);
          if (step.transitLine?.contains('5호선') == true) return Color(0xFF996CAC);
          if (step.transitLine?.contains('6호선') == true) return Color(0xFFCD7C2F);
          if (step.transitLine?.contains('7호선') == true) return Color(0xFF747F00);
          if (step.transitLine?.contains('8호선') == true) return Color(0xFFE6186C);
          if (step.transitLine?.contains('9호선') == true) return Color(0xFFBB8336);
          return Colors.blue;
        case 'bus':
          return Colors.orange;
        default:
          return Colors.purple;
      }
    }

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[stepIndex % colors.length];
  }

  IconData _getStepIcon(TransitStep step) {
    switch (step.mode) {
      case 'WALKING':
        return Icons.directions_walk;
      case 'TRANSIT':
        switch (step.transitType?.toLowerCase()) {
          case 'subway':
            return Icons.subway;
          case 'bus':
            return Icons.directions_bus;
          default:
            return Icons.directions_transit;
        }
      default:
        return Icons.place;
    }
  }

  Set<Marker> _getTransitMarkers() {
    Set<Marker> markers = {};

    markers.add(Marker(
      markerId: MarkerId('origin'),
      position: widget.origin,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(title: '출발지'),
    ));

    markers.add(Marker(
      markerId: MarkerId('destination'),
      position: widget.destination,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: '목적지'),
    ));

    if (!_isTransitMode || _transitSteps.isEmpty) {
      return markers;
    }

    for (int i = 0; i < _transitSteps.length; i++) {
      final step = _transitSteps[i];

      if (step.mode == 'TRANSIT') {
        if (step.departureStopLocation != null && step.departureStop != null) {
          double hue;
          String icon;
          switch (step.transitType?.toLowerCase()) {
            case 'subway':
              hue = BitmapDescriptor.hueBlue;
              icon = '🚇';
              break;
            case 'bus':
              hue = BitmapDescriptor.hueOrange;
              icon = '🚌';
              break;
            default:
              hue = BitmapDescriptor.hueViolet;
              icon = '🚌';
          }

          markers.add(Marker(
            markerId: MarkerId('departure_stop_$i'),
            position: step.departureStopLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
            infoWindow: InfoWindow(
              title: '$icon ${step.departureStop}',
              snippet: '${step.transitLine} 승차 • ${step.departureTime ?? ""}',
            ),
          ));
        }

        if (step.arrivalStopLocation != null &&
            step.arrivalStop != null &&
            step.arrivalStopLocation != step.departureStopLocation) {
          double hue;
          String icon;
          switch (step.transitType?.toLowerCase()) {
            case 'subway':
              hue = BitmapDescriptor.hueBlue;
              icon = '🚇';
              break;
            case 'bus':
              hue = BitmapDescriptor.hueOrange;
              icon = '🚌';
              break;
            default:
              hue = BitmapDescriptor.hueViolet;
              icon = '🚌';
          }

          markers.add(Marker(
            markerId: MarkerId('arrival_stop_$i'),
            position: step.arrivalStopLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
            infoWindow: InfoWindow(
              title: '$icon ${step.arrivalStop}',
              snippet: '${step.transitLine} 하차 • ${step.arrivalTime ?? ""}',
            ),
          ));
        }
      }
    }

    print('✅ 생성된 대중교통 마커 수: ${markers.length}개 (출발지/목적지 포함)');
    return markers;
  }

  Set<Polyline> _getTransitPolylines() {
    Set<Polyline> polylines = {};
    final route = _currentRoute ?? widget.route;  // 추가

    polylines.add(Polyline(
      polylineId: PolylineId('base_route'),
      points: route.points,  // _currentRoute → route
      color: Colors.grey.withOpacity(0.6),
      width: 3,
    ));

    if (!_isTransitMode || _transitSteps.isEmpty || route.points.isEmpty) {
      polylines.clear();
      polylines.add(Polyline(
        polylineId: PolylineId('main_route'),
        points: route.points,  // _currentRoute → route
        color: _getRouteColor(),
        width: 6,
      ));
      return polylines;
    }

    final segmentSize = route.points.length ~/ _transitSteps.length;  // _currentRoute → route

    for (int i = 0; i < _transitSteps.length; i++) {
      final step = _transitSteps[i];

      if (step.mode == 'WALKING') {
        final startIndex = i * segmentSize;
        final endIndex = (i + 1) * segmentSize;

        if (startIndex < route.points.length) {  // _currentRoute → route
          final segmentEndIndex = endIndex < route.points.length
              ? endIndex
              : route.points.length;

          final segmentPoints = route.points.sublist(startIndex, segmentEndIndex);  // _currentRoute → route

          if (segmentPoints.isNotEmpty) {
            polylines.add(Polyline(
              polylineId: PolylineId('walking_$i'),
              points: segmentPoints,
              color: Colors.green,
              width: 5,
              patterns: [PatternItem.dot, PatternItem.gap(8)],
            ));
          }
        }
      }
    }

    return polylines;
  }

  void _showArrivalDialog() {
    _locationTimer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.orange),
            SizedBox(width: 8),
            Text('목적지 도착!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎉 성공적으로 목적지에 도착했습니다!'),
            if (_detailedTransitRoute?.totalFare.isNotEmpty == true) ...[
              SizedBox(height: 8),
              Text('💰 총 교통비: ${_detailedTransitRoute!.totalFare}'),
            ],
            if (_transitSteps.isNotEmpty) ...[
              SizedBox(height: 8),
              Text('🚌 이용한 교통수단: ${_transitSteps.where((s) => s.mode == 'TRANSIT').length}개'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showDetailedSteps() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '상세 경로 안내',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: _transitSteps.length,
                itemBuilder: (context, index) {
                  final step = _transitSteps[index];
                  final isCurrentStep = index == _currentStepIndex;

                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrentStep ? Colors.blue.withOpacity(0.1) : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrentStep
                          ? Border.all(color: Colors.blue, width: 2)
                          : null,
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStepColor(index, step),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getStepIcon(step),
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      title: Text(step.instruction),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${step.duration}'),
                          if (step.transitLine != null)
                            Text('${step.transitLine}'),
                          if (step.departureStop != null && step.arrivalStop != null)
                            Text('${step.departureStop} → ${step.arrivalStop}'),
                        ],
                      ),
                      trailing: isCurrentStep
                          ? Icon(Icons.location_on, color: Colors.blue)
                          : null,
                      onTap: () {
                        setState(() {
                          _currentStepIndex = index;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepCard() {
    if (!_isTransitMode ||
        _transitSteps.isEmpty ||
        _currentStepIndex >= _transitSteps.length) {
      return SizedBox.shrink();
    }

    final currentStep = _transitSteps[_currentStepIndex];

    return Card(
      elevation: 8,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStepColor(_currentStepIndex, currentStep),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStepIcon(currentStep),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currentStepIndex + 1}단계 / ${_transitSteps.length}단계',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        currentStep.instruction,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (currentStep.mode == 'TRANSIT') ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (currentStep.transitLine != null)
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStepColor(_currentStepIndex, currentStep),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              currentStep.transitLine!,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Spacer(),
                          Text(
                            currentStep.duration,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),

                    if (currentStep.departureStop != null && currentStep.arrivalStop != null) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.radio_button_checked, size: 12, color: Colors.green),
                          SizedBox(width: 6),
                          Expanded(child: Text(currentStep.departureStop!, style: TextStyle(fontSize: 12))),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.radio_button_unchecked, size: 12, color: Colors.red),
                          SizedBox(width: 6),
                          Expanded(child: Text(currentStep.arrivalStop!, style: TextStyle(fontSize: 12))),
                        ],
                      ),
                    ],

                    if (currentStep.departureTime != null) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            '출발: ${currentStep.departureTime}',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                          if (currentStep.arrivalTime != null) ...[
                            SizedBox(width: 16),
                            Text(
                              '도착: ${currentStep.arrivalTime}',
                              style: TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInfoPanel() {
    final route = _currentRoute ?? widget.route;  // null이면 widget.route 사용

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.distance,  // _currentRoute → route
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        route.duration,  // _currentRoute → route
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                      if (_detailedTransitRoute?.totalFare.isNotEmpty == true) ...[
                        SizedBox(height: 4),
                        Text(
                          '요금: ${_detailedTransitRoute!.totalFare}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.my_location),
                      onPressed: _updateCamera,
                    ),
                    if (_transitSteps.isNotEmpty) ...[
                      IconButton(
                        icon: Icon(Icons.skip_previous),
                        onPressed: _currentStepIndex > 0 ? () {
                          setState(() {
                            _currentStepIndex--;
                          });
                        } : null,
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_next),
                        onPressed: _currentStepIndex < _transitSteps.length - 1 ? () {
                          setState(() {
                            _currentStepIndex++;
                          });
                        } : null,
                      ),
                    ],
                  ],
                ),
              ],
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
        title: Text('실시간 내비게이션 ${_getTransportModeIcon()}'),
        backgroundColor: _getRouteColor(),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isNavigating ? Icons.pause : Icons.play_arrow),
            onPressed: _isNavigating ? _pauseNavigation : _resumeNavigation,
          ),
          if (_isTransitMode && _transitSteps.isNotEmpty)
            IconButton(
              icon: Icon(Icons.list),
              onPressed: _showDetailedSteps,
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.origin,
              zoom: _isTransitMode ? 12 : 13,
              tilt: _isTransitMode ? 0 : 30,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _updateCurrentLocation();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapType: MapType.normal,
            polylines: _isTransitMode ? _getTransitPolylines() : {
              Polyline(
                polylineId: PolylineId('navigation_route'),
                points: _currentRoutePoints.isNotEmpty ? _currentRoutePoints : widget.route.points, // 🎯 수정
                color: _getRouteColor(),
                width: 6,
              ),
            },
            markers: _isTransitMode ? _getTransitMarkers() : {
              Marker(
                markerId: MarkerId('destination'),
                position: widget.destination,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(title: '목적지'),
              ),
            },
          ),

          if (_isTransitMode && _transitSteps.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildCurrentStepCard(),
            ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomInfoPanel(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}