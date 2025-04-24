import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/schedule_save_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

class SavedScheduleDetailScreen extends StatefulWidget {
  final int scheduleId;

  const SavedScheduleDetailScreen({
    Key? key,
    required this.scheduleId,
  }) : super(key: key);

  @override
  State<SavedScheduleDetailScreen> createState() => _SavedScheduleDetailScreenState();
}

class _SavedScheduleDetailScreenState extends State<SavedScheduleDetailScreen> with SingleTickerProviderStateMixin {
  final ScheduleSaveService _scheduleSaveService = ScheduleSaveService();
  Map<String, dynamic> _scheduleDetail = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  late TabController _tabController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadScheduleDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadScheduleDetail() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final detail = await _scheduleSaveService.getSavedScheduleDetail(widget.scheduleId);
      setState(() {
        _scheduleDetail = detail;
        _isLoading = false;
      });
      _setupMapData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _setupMapData() {
    if (_scheduleDetail.isEmpty ||
        _scheduleDetail['scheduleItems'] == null ||
        _scheduleDetail['scheduleItems'].isEmpty) {
      return;
    }

    // 마커 생성
    List<dynamic> items = _scheduleDetail['scheduleItems'];
    _markers.clear();
    
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      // 위치 정보가 있는 경우에만 마커 추가
      if (item['location'] != null) {
        double? latitude;
        double? longitude;
        
        // 먼저 직접적인 좌표 정보 확인
        if (item.containsKey('latitude') && item.containsKey('longitude')) {
          latitude = double.tryParse(item['latitude'].toString());
          longitude = double.tryParse(item['longitude'].toString());
        }
        
        // 위치 데이터가 없거나 잘못된 경우 무작위 좌표로 대체 (테스트용)
        if (latitude == null || longitude == null || latitude == 0 || longitude == 0) {
          // 서울 중심 좌표: 37.5665, 126.978
          latitude = 37.5665 + (math.Random().nextDouble() * 0.02) - 0.01;  
          longitude = 126.978 + (math.Random().nextDouble() * 0.02) - 0.01;
        }
        
        _markers.add(
          Marker(
            markerId: MarkerId('place_$i'),
            position: LatLng(latitude, longitude),
            infoWindow: InfoWindow(
              title: item['name'] ?? '장소 ${i+1}',
              snippet: _formatTime(item['startTime'], item['endTime']),
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              i == 0 ? BitmapDescriptor.hueGreen : 
              i == items.length - 1 ? BitmapDescriptor.hueRed : 
              BitmapDescriptor.hueAzure
            ),
          ),
        );
      }
    }

    // 경로 라인 생성
    if (_scheduleDetail['segments'] != null && _scheduleDetail['segments'].isNotEmpty) {
      _polylines.clear();
      List<dynamic> segments = _scheduleDetail['segments'];
      
      List<LatLng> points = [];
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        double? latitude;
        double? longitude;
        
        if (item.containsKey('latitude') && item.containsKey('longitude')) {
          latitude = double.tryParse(item['latitude'].toString());
          longitude = double.tryParse(item['longitude'].toString());
        }
        
        if (latitude != null && longitude != null && latitude != 0 && longitude != 0) {
          points.add(LatLng(latitude, longitude));
        }
      }
      
      if (points.length >= 2) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: Colors.blue,
            width: 5,
          ),
        );
      }
    }
  }

  String _formatTime(dynamic startTime, dynamic endTime) {
    if (startTime == null || endTime == null) return '시간 정보 없음';
    try {
      final start = DateTime.parse(startTime.toString());
      final end = DateTime.parse(endTime.toString());
      return '${DateFormat('HH:mm').format(start)} ~ ${DateFormat('HH:mm').format(end)}';
    } catch (e) {
      return '시간 정보 오류';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isLoading ? '일정 로딩 중...' : (_scheduleDetail['scheduleName'] ?? '일정 상세'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: '일정 목록'),
            Tab(text: '지도 보기'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _hasError
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildScheduleListView(),
                    _buildMapView(),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            '일정을 불러올 수 없습니다',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadScheduleDetail,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleListView() {
    if (_scheduleDetail.isEmpty || _scheduleDetail['scheduleItems'] == null) {
      return const Center(child: Text('일정 정보가 없습니다'));
    }

    // 일정 항목 추출
    List<dynamic> items = _scheduleDetail['scheduleItems'];
    if (items.isEmpty) {
      return const Center(child: Text('일정 항목이 없습니다'));
    }

    // 일정 정보 추출
    final scheduleName = _scheduleDetail['scheduleName'] ?? '제목 없음';
    final createdAt = _scheduleDetail['createdAt'] != null
        ? DateFormat('yyyy년 MM월 dd일').format(DateTime.parse(_scheduleDetail['createdAt']))
        : '날짜 정보 없음';
    final expirationDate = _scheduleDetail['expirationDate'] != null
        ? DateFormat('yyyy년 MM월 dd일').format(DateTime.parse(_scheduleDetail['expirationDate']))
        : '만료일 정보 없음';
    final totalDistance = (_scheduleDetail['totalDistance'] ?? 0.0).toStringAsFixed(1);
    final totalTime = _scheduleDetail['totalTime'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 일정 요약 정보
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                scheduleName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '생성일: $createdAt',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '만료일: $expirationDate',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricItem(
                    icon: Icons.place,
                    value: '${items.length}곳',
                    label: '방문 장소',
                  ),
                  _buildMetricItem(
                    icon: Icons.route,
                    value: '$totalDistance km',
                    label: '총 거리',
                  ),
                  _buildMetricItem(
                    icon: Icons.access_time,
                    value: '$totalTime분',
                    label: '소요 시간',
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // 일정 항목 목록
        const Text(
          '방문 일정',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        
        ...List.generate(items.length, (index) {
          final item = items[index];
          final startTime = item['startTime'] != null
              ? DateFormat('MM월 dd일 HH:mm').format(DateTime.parse(item['startTime']))
              : '시작 시간 없음';
          final endTime = item['endTime'] != null
              ? DateFormat('HH:mm').format(DateTime.parse(item['endTime']))
              : '종료 시간 없음';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 헤더 부분
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: index == 0 ? Colors.green[50] :
                           index == items.length - 1 ? Colors.red[50] :
                           Colors.blue[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: index == 0 ? Colors.green :
                                 index == items.length - 1 ? Colors.red :
                                 Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] ?? '장소 이름 없음',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '$startTime ~ $endTime',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 내용 부분
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item['location'] != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['location'],
                                style: TextStyle(
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      
                      if (item['type'] != null) ...[
                        Row(
                          children: [
                            Icon(Icons.category, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              item['type'] == 'FIXED' ? '고정 일정' : '유연한 일정',
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontWeight: item['type'] == 'FLEXIBLE' ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // 다음 장소로의 이동 정보
                if (index < items.length - 1 && _scheduleDetail['segments'] != null && _scheduleDetail['segments'].isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: _buildSegmentInfo(index),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSegmentInfo(int index) {
    if (_scheduleDetail['segments'] == null || 
        _scheduleDetail['segments'].isEmpty || 
        index >= _scheduleDetail['segments'].length) {
      return const SizedBox.shrink();
    }

    final segment = _scheduleDetail['segments'][index];
    final distance = segment['distance'] ?? 0.0;
    final duration = segment['duration'] ?? 0;
    final transportMode = segment['transportMode'] ?? 'WALK';
    
    IconData modeIcon;
    String modeText;
    
    switch (transportMode) {
      case 'WALK':
        modeIcon = Icons.directions_walk;
        modeText = '도보';
        break;
      case 'BUS':
        modeIcon = Icons.directions_bus;
        modeText = '버스';
        break;
      case 'SUBWAY':
        modeIcon = Icons.subway;
        modeText = '지하철';
        break;
      case 'TAXI':
        modeIcon = Icons.local_taxi;
        modeText = '택시';
        break;
      default:
        modeIcon = Icons.directions;
        modeText = '이동';
    }

    return Row(
      children: [
        Icon(modeIcon, color: Colors.blue[700], size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$modeText로 ${distance.toStringAsFixed(1)}km 이동 (약 $duration분)',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapView() {
    if (_markers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '지도에 표시할 위치 정보가 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    // 모든 마커가 보이는 카메라 위치 계산
    LatLngBounds getBounds() {
      double minLat = 90.0, maxLat = -90.0;
      double minLng = 180.0, maxLng = -180.0;
      
      for (Marker marker in _markers) {
        if (marker.position.latitude < minLat) minLat = marker.position.latitude;
        if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
        if (marker.position.longitude < minLng) minLng = marker.position.longitude;
        if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
      }
      
      return LatLngBounds(
        northeast: LatLng(maxLat, maxLng),
        southwest: LatLng(minLat, minLng),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _markers.first.position,
            zoom: 14.0,
          ),
          markers: _markers,
          polylines: _polylines,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            // 모든 마커가 보이도록 카메라 조정
            if (_markers.length > 1) {
              controller.animateCamera(
                CameraUpdate.newLatLngBounds(
                  getBounds(),
                  50.0, // 패딩
                ),
              );
            }
          },
        ),
        // 범례
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('시작', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('경유지', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('종료', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.black87, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}