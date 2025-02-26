// lib/widgets/route_places_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/recommended_place.dart';
import '../models/route_info.dart';
import '../services/place_recommendation_service.dart';
import 'recommended_place_card.dart';
import '../screens/place_recommendations_screen.dart';

class RoutePlacesBottomSheet extends StatefulWidget {
  final RouteInfo route;
  final LatLng currentLocation;

  const RoutePlacesBottomSheet({
    Key? key,
    required this.route,
    required this.currentLocation,
  }) : super(key: key);

  @override
  State<RoutePlacesBottomSheet> createState() => _RoutePlacesBottomSheetState();
}

class _RoutePlacesBottomSheetState extends State<RoutePlacesBottomSheet> {
  final PlaceRecommendationService _recommendationService = PlaceRecommendationService();
  List<RecommendedPlace> _recommendations = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 장소 카테고리
  final List<String> _categories = [
    '전체',
    '식당',
    '카페',
    '관광',
    '쇼핑',
    '숙박',
  ];
  String _selectedCategory = '전체';

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 경로 주변 장소 가져오기
      List<String>? categoryFilter;
      if (_selectedCategory != '전체') {
        categoryFilter = [_selectedCategory];
      }

      _recommendations = await _recommendationService.getPlacesAlongRoute(
        widget.route,
        radius: 1000,
        categories: categoryFilter,
      );
    } catch (e) {
      _errorMessage = '추천 장소를 불러오는 데 실패했습니다: $e';
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
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // 상단 핸들 및 제목
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    // 핸들
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 제목
                    const Text(
                      '경로 주변 추천 장소',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // 카테고리 선택 칩
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = category == _selectedCategory;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                            _loadRecommendations();
                          }
                        },
                      ),
                    );
                  },
                ),
              ),

              // 목록 또는 로딩/에러 표시
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 36, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRecommendations,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
                    : _recommendations.isEmpty
                    ? _buildEmptyState()
                    : _buildRecommendationList(scrollController),
              ),

              // 하단 버튼
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaceRecommendationsScreen(
                            route: widget.route,
                            currentLocation: widget.currentLocation,
                            title: '추천 장소',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('모든 추천 장소 보기'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecommendationList(ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _recommendations.length,
      itemBuilder: (context, index) {
        final place = _recommendations[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RecommendedPlaceCard(
            place: place,
            onTap: () {
              // 상세 정보 표시 (원하는 경우 구현)
            },
            onNavigate: () {
              // 내비게이션 시작
              Navigator.pop(context, place);
            },
          ),
        );
      },
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
                ? '경로 주변에 추천할 장소가 없습니다'
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
              _loadRecommendations();
            },
            child: const Text('다른 카테고리 찾기'),
          ),
        ],
      ),
    );
  }
}