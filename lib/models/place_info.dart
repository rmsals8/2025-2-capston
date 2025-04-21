// models/place_info.dart
class PlaceInfo {
  final String placeName;
  final String crowdLevel;
  final String bestVisitTime;
  final List<String>? nearbyFacilities;
  final Map<String, dynamic>? enhancedPlaceDetails;
  final List<String> visitTips;

  PlaceInfo({
    required this.placeName,
    required this.crowdLevel,
    required this.bestVisitTime,
    this.nearbyFacilities,
    this.enhancedPlaceDetails,
    required this.visitTips,
  });

  factory PlaceInfo.fromJson(Map<String, dynamic> json) {
    return PlaceInfo(
      placeName: json['placeName'] ?? '',
      crowdLevel: json['crowdLevel'] ?? '',
      bestVisitTime: json['bestVisitTime'] ?? '',
      nearbyFacilities: json['nearbyFacilities']?.cast<String>(),
      enhancedPlaceDetails: json['enhancedPlaceDetails'],
      visitTips: (json['visitTips'] as List?)?.cast<String>() ?? [],
    );
  }
}