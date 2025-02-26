// lib/models/recommended_place.dart
class RecommendedPlace {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final String category;
  final double rating;
  final String photoUrl;
  final double distance; // 경로로부터의 거리(m)
  final String reasonForRecommendation; // 추천 이유

  RecommendedPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.category,
    this.rating = 0.0,
    this.photoUrl = '',
    this.distance = 0.0,
    this.reasonForRecommendation = '',
  });
}