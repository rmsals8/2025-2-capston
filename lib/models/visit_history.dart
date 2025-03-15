// lib/models/visit_history.dart
class VisitHistory {
  final String id;
  final String placeName;
  final String placeId;
  final String category;
  final double latitude;
  final double longitude;
  final String address;
  final DateTime visitDate;
  final int visitCount; // 방문 횟수

  // userId 필드 타입을 String에서 dynamic 또는 int로 변경
  final dynamic userId;  // dynamic으로 변경하여 두 타입 모두 처리
  VisitHistory({
    required this.id,
    required this.placeName,
    required this.placeId,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.visitDate,
    required this.userId,  // 매개변수 타입도 동일하게 변경
    this.visitCount = 1,
  });

  factory VisitHistory.fromJson(Map<String, dynamic> json) {
    return VisitHistory(
      id: json['id'].toString(),  // 항상 문자열로 변환
      placeName: json['placeName'],
      placeId: json['placeId'],
      category: json['category'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      address: json['address'],
      visitDate: DateTime.parse(json['visitDate']),
      visitCount: json['visitCount'] ?? 1,
      userId: json['userId'],  // 타입 변환 없이 그대로 사용
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'placeName': placeName,
      'placeId': placeId,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'visitDate': visitDate.toIso8601String(),
      'visitCount': visitCount,
    };
  }

  VisitHistory copyWith({
    String? id,
    String? placeName,
    String? placeId,
    String? category,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? visitDate,
    int? visitCount,
    dynamic userId,  // userId 파라미터 추가
  }) {
    return VisitHistory(
      id: id ?? this.id,
      placeName: placeName ?? this.placeName,
      placeId: placeId ?? this.placeId,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      visitDate: visitDate ?? this.visitDate,
      visitCount: visitCount ?? this.visitCount,
      userId: userId ?? this.userId,  // userId 설정 추가
    );
  }
}