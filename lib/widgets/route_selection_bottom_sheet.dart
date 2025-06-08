// lib/widgets/route_selection_bottom_sheet.dart - API 데이터 포함 버전

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_info.dart';
import '../models/transport_mode.dart';
import '../screens/navigation/navigation_screen.dart';
import '../services/google_transit_service.dart';
import 'package:geolocator/geolocator.dart';

class RouteSelectionBottomSheet extends StatelessWidget {
  final List<RouteInfo> routes;
  final Function(RouteInfo) onRouteSelected;
  final TransportMode transportMode;
  final List<GoogleTransitRoute>? transitRoutes;

  const RouteSelectionBottomSheet({
    Key? key,
    required this.routes,
    required this.onRouteSelected,
    this.transportMode = TransportMode.driving,
    this.transitRoutes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 헤더
          Row(
            children: [
              Text(transportMode.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                '${transportMode.label} 경로 옵션 (${routes.length}개)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 경로 카드들
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: routes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final route = entry.value;

                  return _EnhancedRouteCard(
                    route: route,
                    index: index,
                    transportMode: transportMode,
                    transitRoute: (transitRoutes != null && index < transitRoutes!.length)
                        ? transitRoutes![index]
                        : null,
                    onTap: () => onRouteSelected(route),
                    onNavigate: () => _startNavigation(context, route, index),
                    onShowDetails: () => _showDetailedInfo(context, route, index),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _startNavigation(BuildContext context, RouteInfo route, int routeIndex) async {
    print('🔍 _startNavigation 호출됨 - 교통수단: ${transportMode.name}');
    if (!context.mounted) return;

    // 현재 위치 권한 및 위치 확인
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      LatLng origin;

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        // 위치 권한이 있으면 현재 위치 사용
        try {
          Position currentPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          );
          origin = LatLng(currentPosition.latitude, currentPosition.longitude);
          print('현재 위치에서 네비게이션 시작: ${origin.latitude}, ${origin.longitude}');
        } catch (e) {
          // 현재 위치 획득 실패 시 기존 경로의 시작점 사용
          origin = route.points.first;
          print('현재 위치 획득 실패, 기존 출발점 사용: $e');
        }
      } else {
        // 위치 권한이 없으면 기존 경로의 시작점 사용
        origin = route.points.first;
        print('위치 권한 없음, 기존 출발점 사용');
      }

      // 대중교통인 경우 상세 정보도 함께 전달
      GoogleTransitRoute? selectedTransitRoute;
      if (transportMode == TransportMode.transit &&
          transitRoutes != null &&
          routeIndex < transitRoutes!.length) {
        selectedTransitRoute = transitRoutes![routeIndex];
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            print('🚀 NavigationScreen 생성 - origin: ${origin.latitude}, ${origin.longitude}'); // 🆕 디버그
            print('🚀 NavigationScreen 생성 - destination: ${route.points.last.latitude}, ${route.points.last.longitude}'); // 🆕 디버그

            return NavigationScreen(
              route: route,
              origin: origin,  // 현재 위치 또는 기존 출발점
              destination: route.points.last,
              transportMode: transportMode.name,
              transitRoute: selectedTransitRoute,
            );
          },
        ),
      );
    } catch (e) {
      print('네비게이션 시작 오류: $e');
      // 오류 발생 시 기존 방식으로 실행
      GoogleTransitRoute? selectedTransitRoute;
      if (transportMode == TransportMode.transit &&
          transitRoutes != null &&
          routeIndex < transitRoutes!.length) {
        selectedTransitRoute = transitRoutes![routeIndex];
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NavigationScreen(
            route: route,
            origin: route.points.first,
            destination: route.points.last,
            transportMode: transportMode.name,
            transitRoute: selectedTransitRoute,
          ),
        ),
      );
    }
  }

  // 🆕 상세 정보 다이얼로그 (실제 API 데이터 포함)
  void _showDetailedInfo(BuildContext context, RouteInfo route, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getRouteIcon(route.routeType), color: transportMode.color),
            const SizedBox(width: 8),
            const Text('경로 상세 정보'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 기본 정보
                _buildInfoSection('기본 정보', [
                  _buildDetailRow('소요 시간', route.duration),
                  _buildDetailRow('총 거리', route.distance),
                  _buildDetailRow('경로 설명', route.description),
                  _buildDetailRow('API 출처', _getAPISourceName(route.routeType)),
                ]),

                // 🚌 대중교통 상세 정보
                if (transportMode == TransportMode.transit) ...[
                  const SizedBox(height: 16),
                  _buildTransitDetails(route),
                ],

                // 🚗 자동차 상세 정보
                if (transportMode == TransportMode.driving) ...[
                  const SizedBox(height: 16),
                  _buildDrivingDetails(route),
                ],

                // 🚶‍♂️ 도보 상세 정보
                if (transportMode == TransportMode.walking) ...[
                  const SizedBox(height: 16),
                  _buildWalkingDetails(route),
                ],

                // 추가 정보
                if (route.additionalInfo != null && route.additionalInfo!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildAdditionalInfo(route.additionalInfo!),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startNavigation(context, route, index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: transportMode.color),
            child: const Text('길안내 시작', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🚌 대중교통 상세 정보 위젯
  Widget _buildTransitDetails(RouteInfo route) {
    return _buildInfoSection('🚌 대중교통 정보', [
      if (route.fare != null) _buildDetailRow('요금', route.fare!),
      if (route.transferCount != null) _buildDetailRow('환승 횟수', '${route.transferCount}회'),
      if (route.walkingMinutes != null) _buildDetailRow('도보 시간', '${route.walkingMinutes}분'),
      if (route.lines != null && route.lines!.isNotEmpty)
        _buildDetailRow('이용 노선', route.lines!.join(', ')),
      _buildDetailRow('대기 시간', '평균 5-10분'),
    ]);
  }

  // 🚗 자동차 상세 정보 위젯
  Widget _buildDrivingDetails(RouteInfo route) {
    return _buildInfoSection('🚗 자동차 정보', [
      if (route.avgSpeed != null) _buildDetailRow('평균 속도', '${route.avgSpeed!.round()}km/h'),
      if (route.estimatedCost != null) _buildDetailRow('예상 연료비', '${route.estimatedCost}원'),
      _buildDetailRow('교통 상황', _getTrafficCondition(route.routeType)),
      _buildDetailRow('도로 유형', _getRoadType(route.routeType)),
      if (route.routeType.contains('toll')) _buildDetailRow('톨게이트', '있음'),
    ]);
  }

  // 🚶‍♂️ 도보 상세 정보 위젯
  Widget _buildWalkingDetails(RouteInfo route) {
    return _buildInfoSection('🚶‍♂️ 도보 정보', [
      if (route.calories != null) _buildDetailRow('소모 칼로리', '${route.calories}kcal'),
      if (route.avgSpeed != null) _buildDetailRow('평균 속도', '${route.avgSpeed!.toStringAsFixed(1)}km/h'),
      _buildDetailRow('도로 유형', _getWalkingRoadType(route.routeType)),
      _buildDetailRow('안전도', _getSafetyLevel(route.routeType)),
      _buildDetailRow('경사도', _getInclineLevel(route.routeType)),
    ]);
  }

  // 정보 섹션 빌더
  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  // 상세 정보 행 빌더
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 추가 정보 위젯
  Widget _buildAdditionalInfo(Map<String, dynamic> additionalInfo) {
    return _buildInfoSection('📋 추가 정보',
        additionalInfo.entries.map((entry) =>
            _buildDetailRow(entry.key, entry.value.toString())
        ).toList()
    );
  }

  // 헬퍼 메서드들
  IconData _getRouteIcon(String routeType) {
    if (routeType.contains('google')) return Icons.public;
    if (routeType.contains('kakao')) return Icons.local_taxi;
    if (routeType.contains('tmap')) return Icons.traffic;
    if (routeType.contains('transit')) return Icons.directions_transit;
    return Icons.directions;
  }

  String _getAPISourceName(String routeType) {
    if (routeType.contains('google')) return 'Google Maps';
    if (routeType.contains('kakao')) return 'Kakao 내비';
    if (routeType.contains('tmap')) return 'T맵';
    if (routeType.contains('seoul_metro')) return '서울교통공사';
    if (routeType.contains('seoul_bus')) return '서울시 버스';
    return '내부 계산';
  }

  String _getTrafficCondition(String routeType) {
    if (routeType.contains('tmap')) return '실시간 교통정보 반영';
    if (routeType.contains('google')) return '일반 교통 상황';
    if (routeType.contains('kakao')) return '카카오 교통 데이터';
    return '보통';
  }

  String _getRoadType(String routeType) {
    if (routeType.contains('highway')) return '고속도로 우선';
    if (routeType.contains('local')) return '일반도로 우선';
    return '혼합';
  }

  String _getWalkingRoadType(String routeType) {
    if (routeType.contains('tmap')) return '보행자 전용 도로 우선';
    if (routeType.contains('safe')) return '안전한 길 우선';
    if (routeType.contains('scenic')) return '경치 좋은 길';
    return '일반 보도';
  }

  String _getSafetyLevel(String routeType) {
    if (routeType.contains('safe')) return '높음 (인도 완비)';
    if (routeType.contains('scenic')) return '보통 (공원 경유)';
    return '보통';
  }

  String _getInclineLevel(String routeType) {
    if (routeType.contains('fast')) return '낮음 (평지 위주)';
    if (routeType.contains('scenic')) return '중간 (언덕 포함)';
    return '보통';
  }
}

// 🆕 향상된 경로 카드
class _EnhancedRouteCard extends StatelessWidget {
  final RouteInfo route;
  final int index;
  final TransportMode transportMode;
  final GoogleTransitRoute? transitRoute;
  final VoidCallback onTap;
  final VoidCallback onNavigate;
  final VoidCallback onShowDetails;

  const _EnhancedRouteCard({
    required this.route,
    required this.index,
    required this.transportMode,
    this.transitRoute,
    required this.onTap,
    required this.onNavigate,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 (순위, 시간, 추천 뱃지)
              Row(
                children: [
                  // 순위 표시
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: index == 0 ? transportMode.color : Colors.grey[400],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 추천 뱃지
                  if (index == 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: transportMode.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '추천',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // 시간 정보
                  Expanded(
                    child: Text(
                      route.duration,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: index == 0 ? transportMode.color : Colors.black87,
                      ),
                    ),
                  ),

                  // API 출처 아이콘
                  Icon(
                    _getAPIIcon(route.routeType),
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 🆕 상세 설명 (실제 API 데이터)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.description,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 🆕 추가 정보 표시
                    Row(
                      children: [
                        Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(route.distance, style: TextStyle(fontSize: 12, color: Colors.grey[600])),

                        if (route.fare != null) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.payments, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(route.fare!, style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                        ],

                        if (route.calories != null) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text('${route.calories}kcal', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 액션 버튼들
              Row(
                children: [
                  // 상세 보기 버튼 (항상 활성화)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onShowDetails,
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('상세 보기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: transportMode.color,
                        side: BorderSide(color: transportMode.color),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 길안내 버튼
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onNavigate,
                      icon: const Icon(Icons.navigation, size: 16),
                      label: const Text('길안내'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: transportMode.color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getAPIIcon(String routeType) {
    if (routeType.contains('google')) return Icons.public;
    if (routeType.contains('kakao')) return Icons.local_taxi;
    if (routeType.contains('tmap')) return Icons.traffic;
    return Icons.route;
  }
}