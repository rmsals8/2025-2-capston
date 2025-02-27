// lib/widgets/recommended_place_card.dart
import 'package:flutter/material.dart';
import '../models/recommended_place.dart';
import '../models/visit_history.dart';
import '../services/visit_history_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RecommendedPlaceCard extends StatelessWidget {
  final RecommendedPlace place;
  final VoidCallback? onTap;
  final VoidCallback? onNavigate;
  final bool showDistance;

  const RecommendedPlaceCard({
    Key? key,
    required this.place,
    this.onTap,
    this.onNavigate,
    this.showDistance = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 장소 이미지 또는 아이콘
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: place.photoUrl.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        place.photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          _getCategoryIcon(place.category),
                          size: 30,
                          color: Colors.grey[400],
                        ),
                      ),
                    )
                        : Icon(
                      _getCategoryIcon(place.category),
                      size: 30,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 12),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 평점 및 거리
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 평점
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

                  // 거리
                  if (showDistance)
                    Text(
                      place.distance < 1000
                          ? '${place.distance.toInt()}m'
                          : '${(place.distance / 1000).toStringAsFixed(1)}km',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // 추천 이유
              if (place.reasonForRecommendation.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    place.reasonForRecommendation,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // 액션 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 방문 기록 추가 버튼
                  TextButton.icon(
                    onPressed: () {
                      _addToVisitHistory(context);
                    },
                    icon: const Icon(Icons.bookmark_border, size: 18),
                    label: const Text('저장'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                  // 내비게이션 버튼
                  if (onNavigate != null)
                    TextButton.icon(
                      onPressed: onNavigate,
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('길찾기'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
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

  // 카테고리에 맞는 아이콘 반환
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

  Future<void> _addToVisitHistory(BuildContext context) async {
    try {
      final visitHistoryService = VisitHistoryService();

      // VisitHistory 객체를 직접 전달하는 대신 개별 필드를 전달
      await visitHistoryService.addVisitHistory(
          place.name,
          place.id,
          place.category,
          place.latitude,
          place.longitude,
          place.address
      );

      // 성공 메시지 표시
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('방문 장소로 저장되었습니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}