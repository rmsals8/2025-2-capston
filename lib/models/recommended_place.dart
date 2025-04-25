// lib/models/recommended_place.dart 파일 예시
// 기존 RecommendedPlace 클래스에 photoUrl 필드 추가

class RecommendedPlace {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final String category;
  final double rating;
  final String photoUrl; // 추가된 이미지 URL 필드
  final double distance;
  final String reasonForRecommendation;

  RecommendedPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.category,
    required this.rating,
    this.photoUrl = '', // 기본값은 빈 문자열
    required this.distance,
    required this.reasonForRecommendation,
  });

  // 복사 메서드도 업데이트
  RecommendedPlace copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? address,
    String? category,
    double? rating,
    String? photoUrl,
    double? distance,
    String? reasonForRecommendation,
  }) {
    return RecommendedPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      photoUrl: photoUrl ?? this.photoUrl,
      distance: distance ?? this.distance,
      reasonForRecommendation: reasonForRecommendation ?? this.reasonForRecommendation,
    );
  }
}