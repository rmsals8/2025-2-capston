import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trip_helper/providers/schedule_provider.dart';
import 'package:trip_helper/models/schedule.dart';
import 'package:trip_helper/screens/route/route_list_screen.dart';
import 'package:trip_helper/providers/route_provider.dart';

class OptimizedScheduleScreen extends StatefulWidget {
  final Map<String, dynamic> optimizedData;

  const OptimizedScheduleScreen({
    Key? key,
    required this.optimizedData,
  }) : super(key: key);

  @override
  _OptimizedScheduleScreenState createState() => _OptimizedScheduleScreenState();
}

class _OptimizedScheduleScreenState extends State<OptimizedScheduleScreen> {
  // 선택된 대안 옵션 상태 관리
  Map<String, int> selectedAlternatives = {};

  @override
  Widget build(BuildContext context) {
    // Map에서 필요한 데이터 추출 및 타입 변환
    final optimizedSchedules = (widget.optimizedData['optimizedSchedules'] as List?)?.map((schedule) {
      if (schedule is Map) {
        return Map<String, dynamic>.from(schedule);
      }
      return <String, dynamic>{};
    }).toList() ?? [];

    final alternativeOptions = widget.optimizedData['alternativeOptions'] as Map<String, dynamic>? ?? {};
    final metrics = widget.optimizedData['metrics'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('최적화된 일정'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetricsCard(metrics),
                  const SizedBox(height: 16),
                  _buildScheduleList(optimizedSchedules, alternativeOptions),
                ],
              ),
            ),
          ),
          _buildRouteButton(context, optimizedSchedules),
        ],
      ),
    );
  }

  Widget _buildMetricsCard(Map<String, dynamic> metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '전체 일정 통계',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('총 거리: ${metrics['totalDistance']?.toStringAsFixed(1) ?? '0.0'}km'),
            Text('총 소요시간: ${metrics['totalTime'] ?? '0'}분'),
            Text('예상 비용: ${metrics['totalCost']?.toStringAsFixed(0) ?? '0'}원'),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleList(
      List<Map<String, dynamic>> schedules,
      Map<String, dynamic> alternativeOptions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '최적화된 일정',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: schedules.length,
          itemBuilder: (context, index) {
            final schedule = schedules[index];
            final bool isFlexible = schedule['type'] == 'FLEXIBLE';

            // 주소 정보 추출
            String address = '';
            // 최우선: 상위 레벨의 locationString 확인
            if (schedule['locationString'] != null) {
              address = schedule['locationString'].toString();
            }
            // 다음 우선순위: location 객체 내부 확인
            else if (schedule['location'] is Map) {
              final Map<String, dynamic> locationMap = schedule['location'] as Map<String, dynamic>;
              // location 내부에 locationString이 있으면 사용
              if (locationMap['locationString'] != null) {
                address = locationMap['locationString'].toString();
              }
              // 없으면 name 사용
              else if (locationMap['name'] != null) {
                address = locationMap['name'].toString();
              }
            }
            // location이 JSON 문자열인 경우 (유연 일정에서 자주 발생)
            else if (schedule['location'] is String) {
              String locationStr = schedule['location'].toString();
              if (locationStr.startsWith('{') && locationStr.contains('name')) {
                try {
                  final Map<String, dynamic> locationMap = json.decode(locationStr);
                  if (locationMap['name'] != null) {
                    address = locationMap['name'].toString();
                  } else {
                    address = locationStr; // 파싱 성공했지만 name이 없는 경우
                  }
                } catch (e) {
                  address = locationStr; // 파싱 실패한 경우 원본 문자열 사용
                  print('주소 JSON 파싱 실패: $e');
                }
              } else {
                address = locationStr; // JSON 형식이 아닌 문자열
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(
                      // 유연한 일정인 경우 장소 이름과 함께 표시
                      isFlexible
                          ? "${schedule['name']} (${_extractPlaceName(schedule['location'])})"
                          : schedule['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isFlexible ? Colors.blue : Colors.black,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (address.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                            child: Text(
                              '주소: $address',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        Text(
                          '일정: ${_formatDateTime(schedule['startTime'])} - ${_formatDateTime(schedule['endTime'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    trailing: isFlexible && alternativeOptions.containsKey(schedule['id'])
                        ? TextButton(
                      child: const Text('대안 보기'),
                      onPressed: () => _showAlternatives(
                          context,
                          schedule['id'],
                          alternativeOptions[schedule['id']] ?? []
                      ),
                    )
                        : null,
                  ),

                  // 유연한 일정인 경우 미리 대안 표시 (축소 버전)
                  if (isFlexible && alternativeOptions.containsKey(schedule['id']))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: _buildAlternativesPreview(
                          schedule['id'],
                          alternativeOptions[schedule['id']]
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // 대안 미리보기 위젯
  Widget _buildAlternativesPreview(String scheduleId, List<dynamic> options) {
    if (options.isEmpty) return const SizedBox.shrink();

    // 상위 3개 대안만 표시
    final limitedOptions = options.length > 3 ? options.sublist(0, 3) : options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '다른 장소 옵션:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        ...limitedOptions.map((option) {
          final place = option['place'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(Icons.place, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${place['name']} (${_formatDateTime(option['startTime'])})',
                        style: TextStyle(fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (place['formatted_address'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            place['formatted_address'],
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        if (options.length > 3)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              child: const Text('더보기...', style: TextStyle(fontSize: 12)),
              onPressed: () => _showAlternatives(context, scheduleId, options),
            ),
          ),
      ],
    );
  }

  // 대안 선택 다이얼로그
  void _showAlternatives(BuildContext context, String scheduleId, List<dynamic> options) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.8,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('대체 장소 옵션',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final place = option['place'];
                    final isSelected = selectedAlternatives[scheduleId] == index;

                    return Card(
                      color: isSelected ? Colors.blue[50] : null,
                      child: ListTile(
                        title: Text(place['name'],
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                              child: Text(
                                '주소: ${place['formatted_address'] ?? '주소 정보 없음'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text('${_formatDateTime(option['startTime'])} - ${_formatDateTime(option['endTime'])}'),
                            if (place['rating'] != null)
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 16, color: Colors.amber),
                                  Text(' ${place['rating']}'),
                                ],
                              ),
                            if (place['formatted_address'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  '${place['formatted_address']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[800],
                                    fontStyle: FontStyle.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.blue)
                            : TextButton(
                          child: const Text('선택'),
                          onPressed: () {
                            setState(() {
                              selectedAlternatives[scheduleId] = index;
                            });
                            Navigator.pop(context);

                            // 여기서 선택한 대안을 적용하는 로직 추가
                            // 예: API 호출하여 일정 업데이트
                            _updateScheduleWithAlternative(scheduleId, option);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 선택한 대안으로 일정 업데이트
  void _updateScheduleWithAlternative(String scheduleId, Map<String, dynamic> alternativeOption) {
    // 프로바이더를 통한 일정 업데이트
    try {
      final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);

      // 기존 일정 찾기
      final optimizedSchedules = List<Map<String, dynamic>>.from(
          widget.optimizedData['optimizedSchedules'] as List? ?? []
      );

      for (int i = 0; i < optimizedSchedules.length; i++) {
        if (optimizedSchedules[i]['id'] == scheduleId) {
          // 선택한 대안 정보로 일정 업데이트
          final place = alternativeOption['place'];
          final startTime = alternativeOption['startTime'];
          final endTime = alternativeOption['endTime'];

          // 일정 객체 업데이트
          optimizedSchedules[i]['location'] = place['formatted_address'] ?? '';
          optimizedSchedules[i]['latitude'] = place['location']['lat'];
          optimizedSchedules[i]['longitude'] = place['location']['lng'];
          optimizedSchedules[i]['startTime'] = startTime;
          optimizedSchedules[i]['endTime'] = endTime;

          // 상태 업데이트
          setState(() {
            widget.optimizedData['optimizedSchedules'] = optimizedSchedules;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('일정이 "${place['name']}"으로 업데이트되었습니다.')),
          );

          break;
        }
      }
    } catch (e) {
      print('Error updating schedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 업데이트 중 오류가 발생했습니다: $e')),
      );
    }
  }

// 장소 위치에서 이름만 추출
  String _extractPlaceName(dynamic location) {
    if (location == null) return '';

    // 문자열인 경우
    if (location is String) {
      // JSON 객체인 경우 파싱
      if (location.startsWith('{') && location.endsWith('}')) {
        try {
          final Map<String, dynamic> locationObj = json.decode(location);
          return locationObj['name'] ?? '';
        } catch (e) {
          return location;
        }
      }

      // 주소에서 장소명 추출 시도
      final nameParts = location.split(' ');
      if (nameParts.length > 1) {
        // 마지막 부분이 "점" 또는 "호점"으로 끝나면 해당 부분 반환
        for (int i = nameParts.length - 1; i >= 0; i--) {
          if (nameParts[i].contains('점') || nameParts[i].contains('마트') ||
              nameParts[i].contains('GS') || nameParts[i].contains('CU')) {
            return nameParts.sublist(i).join(' ');
          }
        }
      }

      // 주소의 마지막 부분을 장소명으로 사용
      if (nameParts.length > 2) {
        return nameParts.sublist(nameParts.length - 2).join(' ');
      }

      return location; // 이름 추출 실패시 전체 반환
    }

    // Map인 경우 (이미 파싱된 경우)
    if (location is Map) {
      return location['name'] ?? '';
    }

    return ''; // 기타 경우
  }
// 유틸리티 함수 - 다양한 형태의 위치 데이터에서 좌표 추출
  Map<String, double> extractCoordinates(dynamic locationData) {
    double latitude = 0.0;
    double longitude = 0.0;

    try {
      if (locationData is Map) {
        latitude = _parseDouble(locationData['latitude']) ?? 0.0;
        longitude = _parseDouble(locationData['longitude']) ?? 0.0;
      } else if (locationData is String && locationData.contains('{')) {
        try {
          Map<String, dynamic> locationMap = json.decode(locationData);
          latitude = _parseDouble(locationMap['latitude']) ?? 0.0;
          longitude = _parseDouble(locationMap['longitude']) ?? 0.0;
        } catch (e) {
          print('위치 문자열 파싱 오류: $e');
        }
      }
    } catch (e) {
      print('좌표 추출 오류: $e');
    }

    return {'latitude': latitude, 'longitude': longitude};
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  Widget _buildRouteButton(BuildContext context, List<Map<String, dynamic>> schedules) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            try {
              final routeProvider = context.read<RouteProvider>();

              // 좌표 데이터가 포함된 형태로 변환
              final formattedSchedules = schedules.map((schedule) {
                // 기본 좌표값
                double latitude = schedule['latitude'] ?? 0.0;
                double longitude = schedule['longitude'] ?? 0.0;

                // location 객체에서 좌표 추출
                if (latitude == 0.0 || longitude == 0.0) {
                  if (schedule['location'] is Map) {
                    // Map 형태의 location
                    latitude = schedule['location']['latitude'] ?? latitude;
                    longitude = schedule['location']['longitude'] ?? longitude;
                  } else if (schedule['location'] is String && schedule['location'].toString().startsWith('{')) {
                    // JSON 문자열 형태의 location
                    try {
                      Map<String, dynamic> locationMap = json.decode(schedule['location'].toString());
                      latitude = locationMap['latitude'] ?? latitude;
                      longitude = locationMap['longitude'] ?? longitude;
                    } catch (e) {
                      print('위치 문자열 파싱 오류: $e');
                    }
                  }
                }

                print('좌표 추출 결과: ${schedule['name']} - lat: $latitude, lng: $longitude');

                return {
                  'name': schedule['name'] ?? '',
                  'latitude': latitude,
                  'longitude': longitude,
                  'location': schedule['name'] ?? '',  // location은 문자열로 변환
                  'visitTime': schedule['startTime'] ?? DateTime.now().toIso8601String(),
                  'duration': schedule['duration'] ?? 60,
                };
              }).toList();

              print('Formatted schedules for routes (with extracted coordinates): $formattedSchedules');

              // 경로 생성 요청
              await routeProvider.getRecommendedRoutes(formattedSchedules);

              if (context.mounted) {
                if (routeProvider.routes.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RouteListScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('경로를 생성할 수 없습니다.')),
                  );
                }
              }
            } catch (e) {
              print('Error creating route: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('경로 생성 중 오류가 발생했습니다: $e')),
                );
              }
            }
          },
          child: const Text('경로 생성'),
        ),
      ),
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '';
    try {
      final dt = DateTime.parse(dateTime.toString());
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime.toString();
    }
  }

  double _parseCoordinate(dynamic value) {
    if (value == null) return 0.0;

    // 큰 정수값을 실제 좌표로 변환 (355437482.0 -> 35.5437482)
    if (value is num) {
      if (value.abs() > 1000) {
        return value / 10000000.0;  // 7자리 소수점 이동
      }
      return value.toDouble();
    }

    // 문자열인 경우
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }

    return 0.0;
  }
}