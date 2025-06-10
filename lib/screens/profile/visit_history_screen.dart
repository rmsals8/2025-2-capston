import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/visit_history.dart';
import '../../providers/location_provider.dart';
import '../../services/visit_history_service.dart';
import '../recommendations/history_based_recommendations_screen.dart';
import '../place_recommendations_screen.dart';
import '../navigation/navigation_details_screen.dart';
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

  // 페이징 관련 상태 변수
  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 10; // 한 페이지당 아이템 수
  bool _isFirstPage = true;
  bool _isLastPage = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadData();
    _loadCategoryStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 페이징 처리된 데이터 로드
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 페이징 처리된 API 호출
      final result = await _historyService.getVisitHistoriesPaged(
        category: _selectedCategory,
        page: _currentPage,
        size: _pageSize,
      );

      // 결과 처리
      _histories = result['histories'];
      _totalPages = result['totalPages'];
      _currentPage = result['currentPage'];
      _isFirstPage = result['isFirst'];
      _isLastPage = result['isLast'];

      _categorizedHistories = {'전체': _histories};

      // 카테고리별 분류
      for (var history in _histories) {
        if (_categorizedHistories.containsKey(history.category)) {
          _categorizedHistories[history.category]!.add(history);
        } else {
          _categorizedHistories[history.category] = [history];
        }
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

  Future<void> _loadCategoryStats() async {
    try {
      final stats = await _historyService.getCategoryStats();
      setState(() {
        _categoryCounts = stats.map((key, value) => MapEntry(key, value.toInt()));
      });

      _categories = ['전체'];
      List<MapEntry<String, int>> sortedCategories = _categoryCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      _categories.addAll(sortedCategories.map((e) => e.key));

      _tabController.dispose();
      _tabController = TabController(length: _categories.length, vsync: this);

    } catch (e) {
      print('Error loading category stats: $e');
    }
  }

  // 페이지 변경 메서드
  void _changePage(int newPage) {
    if (newPage >= 0 && newPage < _totalPages) {
      setState(() {
        _currentPage = newPage;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '방문 기록',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.recommend, color: Colors.black),
            onPressed: _navigateToRecommendations,
            tooltip: '맞춤 추천',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
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
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey[600],
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: _categories.map((category) => Tab(
            text: '$category${category != '전체' ? ' (${_categoryCounts[category]})' : ''}',
          )).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _errorMessage != null
          ? _buildErrorView()
          : _histories.isEmpty
          ? _buildEmptyState()
          : Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((category) =>
                  _buildHistoryList(_categorizedHistories[category] ?? [])
              ).toList(),
            ),
          ),
          // 페이지네이션 UI 추가
          if (_totalPages > 1) _buildPagination(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showClearHistoryDialog,
        backgroundColor: Colors.black,
        child: const Icon(Icons.delete, color: Colors.white),
        tooltip: '기록 삭제',
      ),
    );
  }

  // 페이지네이션 UI 위젯
  Widget _buildPagination() {
    // 표시할 페이지 번호의 범위 계산
    int startPage = _currentPage - 2 < 0 ? 0 : _currentPage - 2;
    int endPage = startPage + 4 >= _totalPages ? _totalPages - 1 : startPage + 4;

    // 시작 페이지가 너무 뒤로 밀리지 않도록 조정
    if (endPage - startPage < 4 && startPage > 0) {
      startPage = endPage - 4 < 0 ? 0 : endPage - 4;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 이전 페이지 버튼
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _isFirstPage ? null : () => _changePage(_currentPage - 1),
            color: _isFirstPage ? Colors.grey : Colors.black,
          ),

          // 페이지 번호 버튼들
          for (int i = startPage; i <= endPage; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: i == _currentPage ? null : () => _changePage(i),
                style: ElevatedButton.styleFrom(
                  backgroundColor: i == _currentPage ? Colors.black : Colors.grey[200],
                  foregroundColor: i == _currentPage ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(40, 40),
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontWeight: i == _currentPage ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),

          // 다음 페이지 버튼
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _isLastPage ? null : () => _changePage(_currentPage + 1),
            color: _isLastPage ? Colors.grey : Colors.black,
          ),
        ],
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            '방문 기록이 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '장소를 방문하면 여기에 표시됩니다',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _navigateToRecommendations();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('장소 추천 보기'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<VisitHistory> histories) {
    histories.sort((a, b) => b.visitDate.compareTo(a.visitDate));

    return histories.isEmpty
        ? Center(
      child: Text(
        '${_tabController.index > 0 ? _categories[_tabController.index] : ''} 카테고리의 방문 기록이 없습니다',
        style: TextStyle(color: Colors.grey[600]),
      ),
    )
        : ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: histories.length,
      itemBuilder: (context, index) {
        final history = histories[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(history.category),
                color: Colors.black87,
              ),
            ),
            title: Text(
              history.placeName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
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
                  style: TextStyle(color: Colors.grey[700]),
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
              icon: const Icon(Icons.more_vert, color: Colors.black54),
              onPressed: () => _showHistoryOptions(history),
            ),
            onTap: () => _showHistoryDetails(history),
          ),
        );
      },
    );
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


  // 기존 _showHistoryDetails 메서드를 이것으로 완전히 교체하세요

// 기존 _showHistoryDetails 메서드를 이것으로 완전히 교체하세요

  void _showHistoryDetails(VisitHistory history) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(top: 50),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단 핸들
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // 장소 아이콘과 이름
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _getCategoryIcon(history.category),
                              size: 40,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            history.placeName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              history.category,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 상세 정보 섹션
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          _buildModernDetailRow(
                            Icons.location_on,
                            '주소',
                            history.address,
                            Colors.red,
                          ),
                          const SizedBox(height: 16),
                          _buildModernDetailRow(
                            Icons.access_time,
                            '최근 방문',
                            _formatDate(history.visitDate),
                            Colors.blue,
                          ),
                          const SizedBox(height: 16),
                          _buildModernDetailRow(
                            Icons.repeat,
                            '방문 횟수',
                            '${history.visitCount}회',
                            Colors.green,
                          ),
                          const SizedBox(height: 16),
                          _buildModernDetailRow(
                            Icons.map,
                            '좌표',
                            '${history.latitude.toStringAsFixed(4)}, ${history.longitude.toStringAsFixed(4)}',
                            Colors.orange,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 액션 버튼들
                    Row(
                      children: [
                        // 비슷한 장소 찾기 버튼
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showSimilarPlacesByCategory(history.category);
                            },
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text(
                              '비슷한 장소',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              side: const BorderSide(color: Colors.black),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // 지도에서 보기 버튼
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showMapLocation(history);
                            },
                            icon: const Icon(Icons.navigation, size: 18),
                            label: const Text(
                              '길찾기',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 삭제 버튼
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showDeleteConfirmation(history);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text(
                          '기록 삭제',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

// 현대적인 스타일의 상세 정보 행 위젯
  Widget _buildModernDetailRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

// 삭제 확인 다이얼로그 (현대적인 스타일)
  void _showDeleteConfirmation(VisitHistory history) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 삭제 아이콘
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  size: 32,
                  color: Colors.red[400],
                ),
              ),
              const SizedBox(height: 20),

              // 제목
              const Text(
                '기록 삭제',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),

              // 설명
              Text(
                '${history.placeName}의 방문 기록을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // 버튼들
              Row(
                children: [
                  // 취소 버튼
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 삭제 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteHistory(history);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text(
                        '삭제',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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

// 상세 정보 행을 만드는 헬퍼 메서드도 추가하세요
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showHistoryOptions(VisitHistory history) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // 장소 정보 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getCategoryIcon(history.category),
                        color: Colors.black87,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            history.placeName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            history.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 옵션 목록
              ListTile(
                leading: const Icon(Icons.info, color: Colors.black87),
                title: const Text('상세 정보'),
                onTap: () {
                  Navigator.pop(context);
                  _showHistoryDetails(history);
                },
              ),
              ListTile(
                leading: const Icon(Icons.map, color: Colors.black87),
                title: const Text('지도에서 보기'),
                subtitle: const Text('길찾기 및 경로 확인'),
                onTap: () {
                  Navigator.pop(context);
                  _showMapLocation(history); // ✨ 새로 구현한 메서드 호출
                },
              ),
              ListTile(
                leading: const Icon(Icons.search, color: Colors.black87),
                title: const Text('비슷한 장소 찾기'),
                subtitle: Text('${history.category} 카테고리 추천'),
                onTap: () {
                  Navigator.pop(context);
                  _showSimilarPlacesByCategory(history.category);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('기록 삭제', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteHistory(history);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // _VisitHistoryScreenState 클래스 안에 이 메서드를 추가하세요

  Future<void> _showMapLocation(VisitHistory history) async {
    try {
      print('지도에서 위치 보기: ${history.placeName}');

      // 현재 위치 가져오기
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      LatLng currentLocation;

      try {
        final location = await locationProvider.getCurrentLocation();
        currentLocation = location;
        print('현재 위치: ${currentLocation.latitude}, ${currentLocation.longitude}');
      } catch (e) {
        // 현재 위치를 가져올 수 없으면 기본 위치 사용 (울산)
        currentLocation = LatLng(35.5384, 129.2582);
        print('현재 위치 가져오기 실패, 기본 위치 사용: $e');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('현재 위치를 가져올 수 없어 기본 위치에서 시작합니다'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      print('목적지: ${history.latitude}, ${history.longitude}');

      // NavigationDetailsScreen으로 이동
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NavigationDetailsScreen(
              startLat: currentLocation.latitude,
              startLon: currentLocation.longitude,
              endLat: history.latitude,
              endLon: history.longitude,
              startName: '현재 위치',
              endName: history.placeName,
              transportMode: 'driving', // 기본값으로 자동차 설정
            ),
          ),
        );

        print('NavigationDetailsScreen으로 이동 완료');
      }

    } catch (e) {
      print('지도 보기 오류: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('지도를 열 수 없습니다: $e'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToRecommendations() async {
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

  Future<void> _deleteHistory(VisitHistory history) async {
    try {
      await _historyService.deleteVisitHistory(history.id);

      setState(() {
        _histories.removeWhere((h) => h.id == history.id);

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

      _loadData();
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('방문 기록 전체 삭제'),
        content: const Text('모든 방문 기록을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.black)),
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

      setState(() {
        _histories.clear();
        _categoryCounts.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모든 방문 기록이 삭제되었습니다')),
        );
      }

      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }
}