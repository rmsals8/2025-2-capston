import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_info.dart';
import '../models/transport_mode.dart';
import '../services/google_transit_service.dart';
import '../../screens/navigation/navigation_screen.dart';

class RouteSelectionBottomSheet extends StatelessWidget {
  final List<RouteInfo> routes;
  final Function(RouteInfo) onRouteSelected;
  final TransportMode transportMode;
  final List<GoogleTransitRoute>? transitRoutes; // 구글 대중교통 상세 정보

  const RouteSelectionBottomSheet({
    Key? key,
    required this.routes,
    required this.onRouteSelected,
    this.transportMode = TransportMode.driving,
    this.transitRoutes, // 추가된 파라미터
  }) : super(key: key);

  void _startNavigation(BuildContext context, RouteInfo route, int routeIndex) {
    if (!context.mounted) return;

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
        builder: (context) => NavigationScreen(
          route: route,
          origin: route.points.first,
          destination: route.points.last,
          transportMode: transportMode.name,
          transitRoute: selectedTransitRoute, // 상세 정보 전달
        ),
      ),
    );
  }

  String _getTransportModeIcon() {
    return transportMode.icon;
  }

  String _getTransportModeText() {
    return transportMode.label;
  }

  // 환승 횟수 계산
  int _countTransfers(GoogleTransitRoute? transitRoute) {
    if (transitRoute == null) return 0;

    int transferCount = 0;
    for (int i = 0; i < transitRoute.steps.length - 1; i++) {
      final currentStep = transitRoute.steps[i];
      final nextStep = transitRoute.steps[i + 1];

      // TRANSIT 다음에 TRANSIT이 오면 환승
      if (currentStep.mode == 'TRANSIT' && nextStep.mode == 'TRANSIT') {
        transferCount++;
      }
    }

    return transferCount;
  }

  // 대중교통 상세 정보 다이얼로그
  void _showTransitDetails(BuildContext context, GoogleTransitRoute? transitRoute) {
    if (transitRoute == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.directions_transit, color: Colors.orange),
            SizedBox(width: 8),
            Text('대중교통 상세 정보'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 요약 정보
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('총 소요시간', style: TextStyle(color: Colors.grey[600])),
                        Text(transitRoute.duration, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('총 거리', style: TextStyle(color: Colors.grey[600])),
                        Text(transitRoute.distance, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (transitRoute.totalFare.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('총 요금', style: TextStyle(color: Colors.grey[600])),
                          Text(transitRoute.totalFare, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 단계별 안내
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: transitRoute.steps.length,
                  itemBuilder: (context, index) {
                    final step = transitRoute.steps[index];
                    final isLast = index == transitRoute.steps.length - 1;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 아이콘과 연결선
                        Column(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _getStepColor(step),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getStepIcon(step),
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 2,
                                height: 40,
                                color: Colors.grey[300],
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // 단계 정보
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.instruction,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              if (step.mode == 'TRANSIT') ...[
                                const SizedBox(height: 4),
                                if (step.transitLine != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStepColor(step),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      step.transitLine!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (step.departureStop != null && step.arrivalStop != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${step.departureStop} → ${step.arrivalStop}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                                if (step.departureTime != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '출발: ${step.departureTime}',
                                    style: TextStyle(fontSize: 10, color: Colors.blue),
                                  ),
                                ],
                              ],
                              const SizedBox(height: 4),
                              Text(
                                step.duration,
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Color _getStepColor(TransitStep step) {
    switch (step.mode) {
      case 'WALKING':
        return Colors.green;
      case 'TRANSIT':
        switch (step.transitType?.toLowerCase()) {
          case 'subway':
            return Colors.blue;
          case 'bus':
            return Colors.orange;
          default:
            return Colors.purple;
        }
      default:
        return Colors.grey;
    }
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
          Row(
            children: [
              Text(
                _getTransportModeIcon(),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Text(
                '${_getTransportModeText()} 경로',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...routes.asMap().entries.map((entry) {
            final index = entry.key;
            final route = entry.value;

            // 대중교통인 경우 상세 정보 가져오기
            final transitRoute = (transportMode == TransportMode.transit &&
                transitRoutes != null &&
                index < transitRoutes!.length)
                ? transitRoutes![index]
                : null;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () => onRouteSelected(route),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // 순위 표시
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: index == 0 ? transportMode.color : Colors.grey[400],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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
                              route.duration.split(' • ')[0], // 시간 부분만 표시
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: index == 0 ? transportMode.color : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 대중교통 상세 정보 표시
                      if (transportMode == TransportMode.transit && transitRoute != null) ...[
                        if (transitRoute.summary.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_transit, color: Colors.orange, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    transitRoute.summary,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 8),

                        // 요금 정보
                        if (transitRoute.totalFare.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.payments, size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                '요금: ${transitRoute.totalFare}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 8),

                        // 환승 횟수 표시
                        Row(
                          children: [
                            const Icon(Icons.sync_alt, size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              '환승: ${_countTransfers(transitRoute)}회',
                              style: const TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ],
                        ),
                      ] else ...[
                        // 일반 경로 정보
                        Row(
                          children: [
                            const Icon(Icons.straighten, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '거리: ${route.distance}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                            const SizedBox(width: 16),
                            if (route.points.isNotEmpty) ...[
                              const Icon(Icons.route, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${route.points.length}개 포인트',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // 하단 버튼
                      Row(
                        children: [
                          // 상세 보기 버튼 (대중교통만)
                          if (transportMode == TransportMode.transit) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showTransitDetails(context, transitRoute),
                                icon: const Icon(Icons.list_alt, size: 16),
                                label: const Text('상세 보기'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                  side: const BorderSide(color: Colors.orange),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // 길안내 버튼
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _startNavigation(context, route, index),
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
          }).toList(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}