import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/route.dart';
import '../models/route_segment.dart';
import '../models/schedule.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' ;


class RouteService {
  // static const String baseUrl = 'http://10.0.2.2:8080/api/v1';
  final baseUrl = dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8080/api/v1';
  Future<List<Route>> getRecommendedRoutes(List<Schedule> schedules) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/routes/recommended-path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'schedules': schedules.map((s) => s.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Route.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get route recommendations');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<Map<String, dynamic>> startNavigation(String routeId, double startLat, double startLon) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/navigation/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'routeId': routeId,
          'currentLocation': {
            'latitude': startLat,
            'longitude': startLon,
          },
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to start navigation');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<Map<String, dynamic>> updateLocation(
      String navigationId,
      double lat,
      double lon,
      double? speed,
      double? heading,
      ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/navigation/$navigationId/location'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'latitude': lat,
          'longitude': lon,
          'speed': speed,
          'heading': heading,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to update location');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}