// lib/screens/place_recommendations_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/recommended_place.dart';
import '../models/visit_history.dart';
import '../services/place_recommendation_service.dart';
import '../screens/navigation/navigation_screen.dart';
import '../services/visit_history_service.dart';
import 'dart:math' as math;
import '../models/route_info.dart';
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
  final Set<String> _savedPlaceIds = {}; // 저장된 장소 ID를 추적
  final Map<String, String> _placeIdToVisitHistoryId = {}; // place_id를 visit_history_id에 매핑

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
    _loadSavedPlaces(); // 저장된 장소 목록 로드
  }

  Future<void> _loadSavedPlaces() async {
    try {
      final visitHistoryService = VisitHistoryService();
      final savedPlaces = await visitHistoryService.getVisitHistories();
      setState(() {
        for (var place in savedPlaces) {
          _savedPlaceIds.add(place.placeId);
          _placeIdToVisitHistoryId[place.placeId] = place.id;
        }
      });
    } catch (e) {
      print('저장된 장소 로드 실패: $e');
    }
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // 카테고리 선택 바
          _buildCategorySelector(),

          // 장소 목록 또는 로딩/에러 표시
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
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
              label: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: isSelected,
              selectedColor: Colors.black,
              backgroundColor: Colors.grey[100],
              onSelected: (selected) {
                if (selected && category != _selectedCategory) {
                  setState(() {
                    _selectedCategory = category;
                  });
                  _loadRecommendations();
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide.none,
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
          Text(
            _errorMessage!,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadRecommendations,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
            child: const Text(
              '다시 시도',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
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
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == '전체'
                ? '주변에 추천할 장소가 없습니다'
                : '$_selectedCategory 카테고리의 추천 장소가 없습니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _selectedCategory = '전체';
              });
              _loadRecommendations();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.black),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              '모든 카테고리 보기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _recommendations.length,
      itemBuilder: (context, index) {
        final place = _recommendations[index];
        return _buildPlaceCard(place);
      },
    );
  }

  Widget _buildPlaceCard(RecommendedPlace place) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => _showPlaceDetails(place),
        borderRadius: BorderRadius.circular(8),
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
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(place.category),
                      size: 30,
                      color: Colors.black,
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
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          place.category,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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
                      if (_savedPlaceIds.contains(place.id)) {
                        // 저장 취소 로직
                        try {
                          final visitHistoryService = VisitHistoryService();
                          final visitHistoryId = _placeIdToVisitHistoryId[place.id];

                          if (visitHistoryId != null) {
                            await visitHistoryService.deleteVisitHistory(visitHistoryId);

                            setState(() {
                              _savedPlaceIds.remove(place.id);
                              _placeIdToVisitHistoryId.remove(place.id);
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('저장이 취소되었습니다')),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('저장 취소 실패: $e')),
                          );
                        }
                      } else {
                        // 저장 로직
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

                          // 저장 후 새로 추가된 visit history를 가져와서 ID를 매핑
                          final savedPlaces = await visitHistoryService.getVisitHistories();
                          final newlySavedPlace = savedPlaces.firstWhere(
                                (history) => history.placeId == place.id,
                            orElse: () => throw Exception('저장된 장소를 찾을 수 없습니다'),
                          );

                          setState(() {
                            _savedPlaceIds.add(place.id);
                            _placeIdToVisitHistoryId[place.id] = newlySavedPlace.id;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('방문 장소로 저장되었습니다')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('저장 실패: $e')),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      _savedPlaceIds.contains(place.id) ? Icons.bookmark : Icons.bookmark_border,
                      size: 18,
                    ),
                    label: Text(
                      _savedPlaceIds.contains(place.id) ? '저장됨' : '저장',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                    ),
                  ),

                  // 내비게이션 버튼
                  TextButton.icon(
                    onPressed: () => _navigateToPlace(place),
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text(
                      '길찾기',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
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
      backgroundColor: Colors.white,
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

                  // 장소 아이콘
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getCategoryIcon(place.category),
                        size: 40,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 장소 이름
                  Center(
                    child: Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
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
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        place.category,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

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
                        label: const Text(
                          '길찾기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),

                      // 저장 버튼
                      OutlinedButton.icon(
                        onPressed: () async {
                          if (_savedPlaceIds.contains(place.id)) {
                            // 저장 취소 로직
                            try {
                              final visitHistoryService = VisitHistoryService();
                              final visitHistoryId = _placeIdToVisitHistoryId[place.id];

                              if (visitHistoryId != null) {
                                await visitHistoryService.deleteVisitHistory(visitHistoryId);

                                setState(() {
                                  _savedPlaceIds.remove(place.id);
                                  _placeIdToVisitHistoryId.remove(place.id);
                                });

                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('저장이 취소되었습니다')),
                                );
                              }
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('저장 취소 실패: $e')),
                              );
                            }
                          } else {
                            // 저장 로직
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

                              // 저장 후 새로 추가된 visit history를 가져와서 ID를 매핑
                              final savedPlaces = await visitHistoryService.getVisitHistories();
                              final newlySavedPlace = savedPlaces.firstWhere(
                                    (history) => history.placeId == place.id,
                                orElse: () => throw Exception('저장된 장소를 찾을 수 없습니다'),
                              );

                              setState(() {
                                _savedPlaceIds.add(place.id);
                                _placeIdToVisitHistoryId[place.id] = newlySavedPlace.id;
                              });

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('방문 장소로 저장되었습니다')),
                              );
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('저장 실패: $e')),
                              );
                            }
                          }
                        },
                        icon: Icon(
                          _savedPlaceIds.contains(place.id) ? Icons.bookmark : Icons.bookmark_border,
                        ),
                        label: Text(
                          _savedPlaceIds.contains(place.id) ? '저장됨' : '저장',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToPlace(RecommendedPlace place) {
    // 🔧 NavigationScreen에 맞는 형식으로 RouteInfo 생성
    final origin = widget.currentLocation;
    final destination = LatLng(place.latitude, place.longitude);

    // 간단한 RouteInfo 객체 생성 (직선 경로)
    final routeInfo = RouteInfo(
      points: [origin, destination], // 출발지 → 목적지 직선 경로
      distance: '${_calculateDistance(origin, destination).toStringAsFixed(1)} km',
      duration: '예상 ${(_calculateEstimatedTime(origin, destination)).round()}분',
      samplePoints: [origin, destination], // 샘플 포인트
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreen(
          route: routeInfo,           // ✅ RouteInfo 객체
          origin: origin,             // ✅ 출발지 LatLng
          destination: destination,   // ✅ 도착지 LatLng
          transportMode: 'driving',   // ✅ 교통수단 (소문자)
          transitRoute: null,         // ✅ 대중교통 정보 (없음)
        ),
      ),
    );
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // 지구 반지름 (km)

    final double lat1Rad = start.latitude * (math.pi / 180);
    final double lat2Rad = end.latitude * (math.pi / 180);
    final double dLatRad = (end.latitude - start.latitude) * (math.pi / 180);
    final double dLngRad = (end.longitude - start.longitude) * (math.pi / 180);

    final double a = math.pow(math.sin(dLatRad / 2), 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
            math.pow(math.sin(dLngRad / 2), 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }
// 🆕 예상 시간 계산 헬퍼 메서드
  double _calculateEstimatedTime(LatLng start, LatLng end) {
    final distance = _calculateDistance(start, end);

    // 자동차 기준 평균 속도 40km/h로 계산
    return (distance / 40) * 60; // 분 단위
  }


}