// lib/screens/visit_history_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/visit_history.dart';
import '../services/visit_history_service.dart';
import '../services/location_service.dart';
import '../services/place_recommendation_service.dart';
import '../models/recommended_place.dart';
import '../screens/place_recommendations_screen.dart';

class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({Key? key}) : super(key: key);

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  final VisitHistoryService _historyService = VisitHistoryService();
  final LocationService _locationService = LocationService();

  List<VisitHistory> _histories = [];
  Map<String, int> _categoryCounts = {};
  LatLng? _currentLocation;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 방문 기록 불러오기
      _histories = await _historyService.getVisitHistories();

      // 카테고리별 통계 계산
      _categoryCounts = {};
      for (var history in _histories) {
        _categoryCounts[history.category] = (_categoryCounts[history.category] ?? 0) + 1;
      }

      // 현재 위치 가져오기
      try {
        final position = await _locationService.getCurrentLocation();
        _currentLocation = LatLng(position.latitude, position.longitude);
      } catch (e) {
        print('현재 위치를 가져오는데 실패했습니다: $e');
        // 위치를 가져오지 못해도 화면은 표시
      }

    } catch (e) {
      _errorMessage = '방문 기록을 불러오는데 실패했습니다: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('방문 기록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _showClearHistoryDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      )
          : _histories.isEmpty
          ? _buildEmptyState()
          : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            '방문 기록이 없습니다',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            '장소를 방문하면 여기에 표시됩니다',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 방문 통계 카드
          _buildStatisticsCard(),
          const SizedBox(height: 24),

          // 카테고리별 통계
          if (_categoryCounts.isNotEmpty) ...[
            const Text(
              '카테고리별 방문',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildCategoryStats(),
            const SizedBox(height: 24),
          ],

          // 최근 방문 목록
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '최근 방문',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_currentLocation != null)
                TextButton(
                  onPressed: () => _showSimilarPlaces(),
                  child: const Text('비슷한 장소 찾기'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildVisitList(),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '방문 통계',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.place,
                  value: _histories.length.toString(),
                  label: '총 방문 장소',
                ),
                _buildStatItem(
                  icon: Icons.category,
                  value: _categoryCounts.length.toString(),
                  label: '방문 카테고리',
                ),
                _buildStatItem(
                  icon: Icons.calendar_today,
                  value: _getRecentVisitCount().toString(),
                  label: '이번 달 방문',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryStats() {
    // 카테고리별로 정렬
    final sortedCategories = _categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 최대값 계산
    final maxCount = sortedCategories.isNotEmpty
        ? sortedCategories.first.value.toDouble()
        : 1.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: sortedCategories
              .take(5) // 상위 5개만 표시
              .map((entry) => _buildCategoryBar(
            category: entry.key,
            count: entry.value,
            maxCount: maxCount,
          ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryBar({
    required String category,
    required int count,
    required double maxCount,
  }) {
    final double percentage = count / maxCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              category,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                // 배경 바
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // 진행 바
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _histories.length,
      itemBuilder: (context, index) {
        final history = _histories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
              child: Icon(
                _getCategoryIcon(history.category),
                color: Theme.of(context).primaryColor,
              ),
            ),
            title: Text(
              history.placeName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  history.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(history.visitDate)} • ${history.visitCount}회 방문',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showHistoryOptions(history),
            ),
            onTap: () => _showHistoryDetails(history),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '오늘';
    } else if (difference.inDays == 1) {
      return '어제';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${date.year}.${date.month}.${date.day}';
    }
  }

  int _getRecentVisitCount() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    return _histories
        .where((h) => h.visitDate.isAfter(firstDayOfMonth))
        .length;
  }

  IconData _getCategoryIcon(String category) {
    final lowerCategory = category.toLowerCase();

    if (lowerCategory.contains('식당') ||
        lowerCategory.contains('음식') ||
        lowerCategory.contains('레스토랑')) {
      return Icons.restaurant;
    } else if (lowerCategory.contains('카페') ||
        lowerCategory.contains('coffee')) {
      return Icons.coffee;
    } else if (lowerCategory.contains('쇼핑') ||
        lowerCategory.contains('마트')) {
      return Icons.shopping_bag;
    } else if (lowerCategory.contains('숙소') ||
        lowerCategory.contains('호텔')) {
      return Icons.hotel;
    } else if (lowerCategory.contains('관광') ||
        lowerCategory.contains('명소')) {
      return Icons.photo_camera;
    } else if (lowerCategory.contains('병원') ||
        lowerCategory.contains('약국')) {
      return Icons.local_hospital;
    } else if (lowerCategory.contains('주유소')) {
      return Icons.local_gas_station;
    } else if (lowerCategory.contains('주차')) {
      return Icons.local_parking;
    }

    return Icons.place;
  }

  Future<void> _showHistoryOptions(VisitHistory history) async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.place),
                title: const Text('상세 정보'),
                onTap: () {
                  Navigator.pop(context);
                  _showHistoryDetails(history);
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('비슷한 장소 찾기'),
                onTap: () {
                  Navigator.pop(context);
                  _showSimilarPlacesByCategory(history.category);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('기록 삭제'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteHistory(history);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHistoryDetails(VisitHistory history) {
    // TODO: 장소 상세 정보 표시
  }

  Future<void> _showSimilarPlaces() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 위치를 가져올 수 없습니다')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceRecommendationsScreen(
          currentLocation: _currentLocation!,
          title: '방문 기록 기반 추천',
        ),
      ),
    );
  }

  Future<void> _showSimilarPlacesByCategory(String category) async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 위치를 가져올 수 없습니다')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceRecommendationsScreen(
          currentLocation: _currentLocation!,
          title: '$category 추천',
          category: category,
        ),
      ),
    );
  }

  Future<void> _deleteHistory(VisitHistory history) async {
    try {
      await _historyService.deleteVisitHistory(history.id);

      // 목록 갱신
      setState(() {
        _histories.removeWhere((h) => h.id == history.id);

        // 카테고리 카운트 갱신
        if (_categoryCounts[history.category] != null) {
          _categoryCounts[history.category] = _categoryCounts[history.category]! - 1;
          if (_categoryCounts[history.category] == 0) {
            _categoryCounts.remove(history.category);
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('방문 기록이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  Future<void> _showClearHistoryDialog() async {
    if (_histories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제할 방문 기록이 없습니다')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('방문 기록 전체 삭제'),
        content: const Text('모든 방문 기록을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllHistories();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllHistories() async {
    try {
      await _historyService.clearAllVisitHistories();

      // 목록 갱신
      setState(() {
        _histories.clear();
        _categoryCounts.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모든 방문 기록이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }
}