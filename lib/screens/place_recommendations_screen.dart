// lib/screens/place_recommendations_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/recommended_place.dart';
import '../models/visit_history.dart';
import '../services/place_recommendation_service.dart';
import '../screens/navigation/navigation_screen.dart';
import '../services/visit_history_service.dart';
class PlaceRecommendationsScreen extends StatefulWidget {
  final LatLng currentLocation;
  final String title;
  final String? category;
  // route 매개변수 추가 (선택적으로 만들기)
  final dynamic route;

  const PlaceRecommendationsScreen({
    Key? key,
    required this.currentLocation,
    required this.title,
    this.category,
    this.route,
  }) : super(key: key);

  @override
  State<PlaceRecommendationsScreen> createState() => _PlaceRecommendationsScreenState();
}

class _PlaceRecommendationsScreenState extends State<PlaceRecommendationsScreen> {
  final PlaceRecommendationService _recommendationService = PlaceRecommendationService();
  List<RecommendedPlace> _recommendations = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 카테고리 목록
  final List<String> _categories = [
    '전체',
    '식당',
    '카페',
    '쇼핑',
    '관광',
    '엔터테인먼트',
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
      // 카테고리 필터링
      String? categoryFilter = _selectedCategory == '전체' ? null : _selectedCategory;
      if (widget.category != null) {
        categoryFilter = widget.category;
        _selectedCategory = widget.category!;
      }

      // 위치 기반 추천 장소 검색
      _recommendations = await _recommendationService.getNearbyPlaces(
        widget.currentLocation,
        radius: 2000, // 2km 반경
        category: categoryFilter,
      );

      print('추천 장소 개수: ${_recommendations.length}');

    } catch (e) {
      _errorMessage = '추천 장소를 불러오는 데 실패했습니다: $e';
      print('장소 추천 오류: $e');
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
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // 카테고리 선택 바
          _buildCategorySelector(),

          // 장소 목록 또는 로딩/에러 표시
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
                if (selected && category != _selectedCategory) {
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
            onPressed: _loadRecommendations,
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
                ? '주변에 추천할 장소가 없습니다'
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
            child: const Text('모든 카테고리 보기'),
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
        return _buildPlaceCard(place);
      },
    );
  }

  Widget _buildPlaceCard(RecommendedPlace place) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showPlaceDetails(place),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 장소 아이콘
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(place.category),
                      size: 30,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 장소 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          place.category,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          place.address,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 거리 및 평점
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 거리
                  Text(
                    place.distance < 1000
                        ? '${place.distance.toInt()}m'
                        : '${(place.distance / 1000).toStringAsFixed(1)}km',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),

                  // 평점 (있는 경우만)
                  if (place.rating > 0)
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          place.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // 액션 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 저장 버튼
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        final visitHistoryService = VisitHistoryService();
                        await visitHistoryService.addVisitHistory(
                            place.name,
                            place.id,
                            place.category,
                            place.latitude,
                            place.longitude,
                            place.address
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('방문 장소로 저장되었습니다')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('저장 실패: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.bookmark_border, size: 18),
                    label: const Text('저장'),
                  ),

                  // 내비게이션 버튼
                  TextButton.icon(
                    onPressed: () => _navigateToPlace(place),
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('길찾기'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

  void _showPlaceDetails(RecommendedPlace place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 핸들
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

                  // 장소 아이콘
                  Align(
                    alignment: Alignment.center,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: Icon(
                        _getCategoryIcon(place.category),
                        size: 40,
                        color: Colors.blue,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 장소 이름
                  Center(
                    child: Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 카테고리
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        place.category,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 주소
                  _buildDetailItem(Icons.location_on, '주소', place.address),

                  // 거리
                  _buildDetailItem(
                    Icons.directions,
                    '거리',
                    place.distance < 1000
                        ? '${place.distance.toInt()}m'
                        : '${(place.distance / 1000).toStringAsFixed(1)}km',
                  ),

                  // 평점 (있는 경우)
                  if (place.rating > 0)
                    _buildDetailItem(
                      Icons.star,
                      '평점',
                      place.rating.toStringAsFixed(1),
                    ),

                  const SizedBox(height: 32),

                  // 액션 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 내비게이션 버튼
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToPlace(place);
                        },
                        icon: const Icon(Icons.navigation),
                        label: const Text('길찾기'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),

                      // 저장 버튼
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('방문 장소로 저장되었습니다')),
                          );
                        },
                        icon: const Icon(Icons.bookmark_border),
                        label: const Text('저장'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToPlace(RecommendedPlace place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreen(
          startLocation: widget.currentLocation,
          endLocation: LatLng(place.latitude, place.longitude),
          transportMode: 'DRIVING',
        ),
      ),
    );
  }
}