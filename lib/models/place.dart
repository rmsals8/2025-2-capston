class Place {
  final String id;
  final String name;
  final String type;
  final DateTime? visitDate;
  final double latitude;
  final double longitude;

  Place({
    required this.id,
    required this.name,
    required this.type,
    this.visitDate,
    required this.latitude,
    required this.longitude,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      visitDate: json['visit_date'] != null ? DateTime.parse(json['visit_date']) : null,
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'visit_date': visitDate?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}