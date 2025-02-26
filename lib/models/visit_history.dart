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

  VisitHistory({
    required this.id,
    required this.placeName,
    required this.placeId,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.visitDate,
    this.visitCount = 1,
  });

  factory VisitHistory.fromJson(Map<String, dynamic> json) {
    return VisitHistory(
      id: json['id'],
      placeName: json['placeName'],
      placeId: json['placeId'],
      category: json['category'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      address: json['address'],
      visitDate: DateTime.parse(json['visitDate']),
      visitCount: json['visitCount'] ?? 1,
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
    );
  }
}