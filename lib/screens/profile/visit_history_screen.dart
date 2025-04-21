// lib/screens/profile/visit_history_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/visit_history.dart';
import '../../providers/location_provider.dart';
import '../../services/visit_history_service.dart';
import '../recommendations/history_based_recommendations_screen.dart';
import '../place_recommendations_screen.dart';

class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({Key? key}) : super(key: key);

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> with TickerProviderStateMixin {
  final VisitHistoryService _historyService = VisitHistoryService();

  List<VisitHistory> _histories = [];
  Map<String, int> _categoryCounts = {};
  Map<String, List<VisitHistory>> _categorizedHistories = {};
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;
  List<String> _categories = ['전체'];
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this); // 초기값으로 1개 탭
    _loadData();
    _loadCategoryStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 방문 기록 불러오기
      _histories = await _historyService.getVisitHistories(
          category: _selectedCategory
      );

      // 카테고리별 분류 및 통계 계산
      _categoryCounts = {};
      _categorizedHistories = {'전체': _histories};

      for (var history in _histories) {
        // 카테고리 카운트 증가
        _categoryCounts[history.category] = (_categoryCounts[history.category] ?? 0) + 1;

        // 카테고리별 리스트에 추가
        if (_categorizedHistories.containsKey(history.category)) {
          _categorizedHistories[history.category]!.add(history);
        } else {
          _categorizedHistories[history.category] = [history];
        }
      }

      // 카테고리 목록 업데이트 (방문 횟수 많은 순으로 정렬)
      _categories = ['전체'];
      List<MapEntry<String, int>> sortedCategories = _categoryCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      _categories.addAll(sortedCategories.map((e) => e.key));

      // 탭 컨트롤러 재생성
      _tabController.dispose();
      _tabController = TabController(length: _categories.length, vsync: this);

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

  Future<void> _loadCategoryStats() async {
    try {
      final stats = await _historyService.getCategoryStats();
      setState(() {
        _categoryCounts = stats.map((key, value) => MapEntry(key, value.toInt()));
      });
    } catch (e) {
      print('Error loading category stats: $e');
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
            icon: const Icon(Icons.recommend),
            onPressed: _navigateToRecommendations,
            tooltip: '맞춤 추천',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _showClearHistoryDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'clear',
                child: Text('모든 기록 삭제'),
              ),
            ],
          ),
        ],
        bottom: _isLoading || _errorMessage != null ? null : TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _categories.map((category) => Tab(
            text: '$category${category != '전체' ? ' (${_categoryCounts[category]})' : ''}',
          )).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : _histories.isEmpty
          ? _buildEmptyState()
          : TabBarView(
        controller: _tabController,
        children: _categories.map((category) =>
            _buildHistoryList(_categorizedHistories[category] ?? [])
        ).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showClearHistoryDialog,
        child: const Icon(Icons.delete),
        tooltip: '기록 삭제',
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // 추천 화면으로 이동
              _navigateToRecommendations();
            },
            child: const Text('장소 추천 보기'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<VisitHistory> histories) {
    // 날짜별로 정렬 (최신순)
    histories.sort((a, b) => b.visitDate.compareTo(a.visitDate));

    return histories.isEmpty
        ? Center(
      child: Text(
        '${_tabController.index > 0 ? _categories[_tabController.index] : ''} 카테고리의 방문 기록이 없습니다',
        style: const TextStyle(color: Colors.grey),
      ),
    )
        : ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: histories.length,
      itemBuilder: (context, index) {
        final history = histories[index];
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

  Widget _buildStatisticsCard() {
    int totalVisits = _histories.fold(0, (sum, history) => sum + history.visitCount);
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.place,
              value: _histories.length.toString(),
              label: '방문 장소',
            ),
            _buildStatItem(
              icon: Icons.repeat,
              value: totalVisits.toString(),
              label: '총 방문 횟수',
            ),
            _buildStatItem(
              icon: Icons.category,
              value: _categoryCounts.length.toString(),
              label: '카테고리',
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  void _navigateToRecommendations() async {
    // 현재 위치 확인
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const HistoryBasedRecommendationsScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('추천 화면을 열 수 없습니다: $e')),
      );
    }
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
    // 장소 상세 정보 표시 (구현 예정)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(history.placeName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('카테고리: ${history.category}'),
            const SizedBox(height: 8),
            Text('주소: ${history.address}'),
            const SizedBox(height: 8),
            Text('최근 방문: ${_formatDate(history.visitDate)}'),
            const SizedBox(height: 8),
            Text('방문 횟수: ${history.visitCount}회'),
            const SizedBox(height: 16),
            Text('좌표: ${history.latitude}, ${history.longitude}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 지도에서 위치 보기 기능 구현 (향후 추가)
            },
            child: const Text('지도에서 보기'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSimilarPlaces() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    try {
      LatLng currentLocation = await locationProvider.getCurrentLocation();

      if (!mounted) return;

      // 카테고리 기반 추천 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlaceRecommendationsScreen(
            currentLocation: currentLocation,
            title: '방문 기록 기반 추천',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 위치를 가져올 수 없습니다')),
      );
    }
  }

  Future<void> _showSimilarPlacesByCategory(String category) async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    try {
      LatLng currentLocation = await locationProvider.getCurrentLocation();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlaceRecommendationsScreen(
            currentLocation: currentLocation,
            title: '$category 추천',
            category: category,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 위치를 가져올 수 없습니다')),
      );
    }
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

      _loadData(); // 데이터 다시 로드
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
      await _historyService.deleteAllVisitHistories();

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

      _loadData(); // 데이터 다시 로드
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  int _getRecentVisitCount() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    return _histories
        .where((h) => h.visitDate.isAfter(firstDayOfMonth))
        .length;
  }
}