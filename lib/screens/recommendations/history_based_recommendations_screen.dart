// lib/screens/recommendations/history_based_recommendations_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/recommended_place.dart';
import '../../providers/location_provider.dart';
import '../../services/place_recommendation_service.dart';
import '../../services/visit_history_service.dart';
import '../../widgets/recommended_place_card.dart';

class HistoryBasedRecommendationsScreen extends StatefulWidget {
  const HistoryBasedRecommendationsScreen({Key? key}) : super(key: key);

  @override
  State<HistoryBasedRecommendationsScreen> createState() => _HistoryBasedRecommendationsScreenState();
}

class _HistoryBasedRecommendationsScreenState extends State<HistoryBasedRecommendationsScreen> {
  final PlaceRecommendationService _recommendationService = PlaceRecommendationService();
  final VisitHistoryService _historyService = VisitHistoryService();

  List<RecommendedPlace> _recommendations = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 사용자의 주요 카테고리
  List<String> _userCategories = [];
  String _selectedCategory = '전체';

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
      // 사용자 위치 가져오기
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final currentLocation = await locationProvider.getCurrentLocation();

      // 방문 기록에서 자주 방문한 카테고리 분석
      final frequentPlaces = await _historyService.getFrequentlyVisitedPlaces();

      // 카테고리 통계
      final Map<String, int> categoryCount = {};
      for (var place in frequentPlaces) {
        categoryCount[place.category] = (categoryCount[place.category] ?? 0) + 1;
      }

      // 자주 방문한 카테고리 추출 (내림차순 정렬)
      _userCategories = categoryCount.keys.toList();
      _userCategories.sort((a, b) =>
          (categoryCount[b] ?? 0).compareTo(categoryCount[a] ?? 0));

      // 선호 카테고리가 없으면 빈 결과
      if (_userCategories.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '방문 기록이 충분하지 않습니다. 더 많은 장소를 방문해보세요!';
        });
        return;
      }

      // 추천 받기
      _recommendations = await _recommendationService.getRecommendationsBasedOnHistory(
        currentLocation,
        limit: 10,
        radius: 5000, // 5km 반경
      );

      // 선택 카테고리 기본값 설정
      if (_userCategories.isNotEmpty) {
        _selectedCategory = '전체';
        // 카테고리 목록 맨 앞에 '전체' 추가
        _userCategories = ['전체', ..._userCategories];
      }

    } catch (e) {
      setState(() {
        _errorMessage = '추천을 불러오는데 실패했습니다: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 카테고리 변경 시 호출
  Future<void> _updateRecommendations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final currentLocation = await locationProvider.getCurrentLocation();

      if (_selectedCategory == '전체') {
        // 전체 카테고리 추천
        _recommendations = await _recommendationService.getRecommendationsBasedOnHistory(
          currentLocation,
          limit: 10,
          radius: 5000,
        );
      } else {
        // 특정 카테고리 추천
        _recommendations = await _recommendationService.getRecommendationsByCategory(
          _selectedCategory,
          currentLocation,
          limit: 10,
          radius: 5000,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = '추천을 불러오는데 실패했습니다: $e';
      });
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
        title: const Text('나를 위한 추천'),
      ),
      body: Column(
        children: [
          // 카테고리 선택 영역
          _buildCategorySelector(),

          // 본문 영역 (로딩/에러/결과)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildErrorView()
                : _recommendations.isEmpty
                ? _buildEmptyState()
                : _buildRecommendationList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _userCategories.length,
        itemBuilder: (context, index) {
          final category = _userCategories[index];
          final isSelected = category == _selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                if (selected && category != _selectedCategory) {
                  setState(() {
                    _selectedCategory = category;
                  });
                  _updateRecommendations();
                }
              },
            ),
          );
        },
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
            Icons.search_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == '전체'
                ? '추천할 장소가 없습니다'
                : '$_selectedCategory 카테고리의 추천 장소가 없습니다',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _selectedCategory = '전체';
              });
              _updateRecommendations();
            },
            child: const Text('다른 카테고리 찾기'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recommendations.length,
      itemBuilder: (context, index) {
        final place = _recommendations[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: RecommendedPlaceCard(
            place: place,
            onTap: () {
              // 상세 정보 표시 (필요에 따라 구현)
            },
            onNavigate: () {
              // 내비게이션 시작
              // 내비게이션 화면으로 이동하는 코드 (생략)
            },
          ),
        );
      },
    );
  }
}