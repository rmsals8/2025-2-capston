import 'package:flutter/material.dart';
import '../models/route_info.dart';
import '../services/google_transit_service.dart'; // TransitStep import

class DetailedTransitStepsWidget extends StatelessWidget {
  final RouteInfo route;
  final List<TransitStep> steps; // google_transit_service.dart의 TransitStep 사용

  const DetailedTransitStepsWidget({
    Key? key,
    required this.route,
    required this.steps,
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
              Icon(Icons.directions_transit, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '상세 경로 안내',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${route.duration} • ${route.distance}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 단계별 안내
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: steps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final step = entry.value;
                  final isLast = index == steps.length - 1;

                  return _StepItem(
                    step: step,
                    isLast: isLast,
                    stepNumber: index + 1,
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 하단 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.navigation),
              label: Text('길안내 시작'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final TransitStep step;
  final bool isLast;
  final int stepNumber;

  const _StepItem({
    required this.step,
    required this.isLast,
    required this.stepNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 아이콘과 연결선
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getStepColor(),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: _getStepIcon(),
              ),
            ),
            if (!isLast)
              Container(
                width: 3,
                height: 60,
                margin: EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),

        const SizedBox(width: 16),

        // 단계 정보
        Expanded(
          child: Container(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 단계 번호와 주요 정보
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStepColor().withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$stepNumber',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getStepColor(),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getStepTitle(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                // 상세 설명
                Text(
                  step.instruction,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),

                // 대중교통 상세 정보
                if (step.mode == 'TRANSIT' && step.departureStop != null) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (step.transitLine != null) ...[
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getLineColor() ?? _getStepColor(),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  step.transitLine!,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                _getTransitTypeText(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Icon(Icons.radio_button_checked, size: 12, color: Colors.green),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                step.departureStop!,
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.radio_button_unchecked, size: 12, color: Colors.red),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                step.arrivalStop ?? '목적지',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        if (step.departureTime != null && step.arrivalTime != null) ...[
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 12, color: Colors.blue),
                              SizedBox(width: 4),
                              Text(
                                '${step.departureTime} → ${step.arrivalTime}',
                                style: TextStyle(fontSize: 11, color: Colors.blue),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // 시간 및 거리
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                    SizedBox(width: 4),
                    Text(
                      step.duration,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (step.distance != null) ...[
                      SizedBox(width: 12),
                      Icon(Icons.straighten, size: 16, color: Colors.grey[500]),
                      SizedBox(width: 4),
                      Text(
                        step.distance!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getStepTitle() {
    switch (step.mode) {
      case 'WALKING':
        return '도보 이동';
      case 'TRANSIT':
        switch (step.transitType?.toLowerCase()) {
          case 'subway':
            return '지하철 이용';
          case 'bus':
            return '버스 이용';
          case 'train':
            return '기차 이용';
          default:
            return '대중교통 이용';
        }
      default:
        return '이동';
    }
  }

  String _getTransitTypeText() {
    switch (step.transitType?.toLowerCase()) {
      case 'subway':
        return '지하철';
      case 'bus':
        return '버스';
      case 'train':
        return '기차';
      default:
        return '대중교통';
    }
  }

  Color _getStepColor() {
    switch (step.mode) {
      case 'WALKING':
        return Colors.green;
      case 'TRANSIT':
        switch (step.transitType?.toLowerCase()) {
          case 'subway':
            return Colors.blue;
          case 'bus':
            return Colors.orange;
          case 'train':
            return Colors.purple;
          default:
            return Colors.orange;
        }
      default:
        return Colors.grey;
    }
  }

  Color? _getLineColor() {
    // step.lineColor가 문자열로 저장되어 있다면 파싱
    if (step.lineColor != null && step.lineColor!.isNotEmpty) {
      try {
        String hex = step.lineColor!.replaceAll('#', '');
        if (hex.length == 6) {
          return Color(int.parse('FF$hex', radix: 16));
        }
      } catch (e) {
        print('색상 파싱 오류: $e');
      }
    }
    return null;
  }

  Widget _getStepIcon() {
    switch (step.mode) {
      case 'WALKING':
        return Icon(Icons.directions_walk, color: Colors.white, size: 18);
      case 'TRANSIT':
        switch (step.transitType?.toLowerCase()) {
          case 'subway':
            return Icon(Icons.subway, color: Colors.white, size: 18);
          case 'bus':
            return Icon(Icons.directions_bus, color: Colors.white, size: 18);
          case 'train':
            return Icon(Icons.train, color: Colors.white, size: 18);
          default:
            return Icon(Icons.directions_transit, color: Colors.white, size: 18);
        }
      default:
        return Icon(Icons.place, color: Colors.white, size: 18);
    }
  }
}