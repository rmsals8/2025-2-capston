import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_model.dart';
import '../models/navigation_status.dart';


class NavigationService {
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1/navigation';
  final http.Client _client;

  NavigationService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<RouteModel>> getRoutes(LatLng start, LatLng end) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/routes?'
            'startLat=${start.latitude}&'
            'startLon=${start.longitude}&'
            'endLat=${end.latitude}&'
            'endLon=${end.longitude}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => RouteModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load routes');
      }
    } catch (e) {
      throw Exception('Error getting routes: $e');
    }
  }

  Future<String> startNavigation(String routeId, LatLng currentLocation) async {
    try {
      print('Starting navigation with routeId: $routeId');
      print('Current location: ${currentLocation.latitude}, ${currentLocation.longitude}');

      final response = await _client.post(
        Uri.parse('$baseUrl/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'routeId': routeId,
          'currentLocation': {
            'latitude': currentLocation.latitude,
            'longitude': currentLocation.longitude,
          },
        }),
      );

      print('Navigation API response status: ${response.statusCode}');
      print('Navigation API response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['navigationId'];
      } else {
        throw Exception('Failed to start navigation: ${response.statusCode}');
      }
    } catch (e) {
      print('Navigation start error: $e');
      throw Exception('Error starting navigation: $e');
    }
  }

  Stream<NavigationStatus> getNavigationUpdates(String navigationId) {
    final controller = StreamController<NavigationStatus>();

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/$navigationId/status'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          controller.add(NavigationStatus.fromJson(data));
        } else {
          controller.addError('Failed to get navigation updates');
          timer.cancel();
        }
      } catch (e) {
        controller.addError('Error getting navigation updates: $e');
        timer.cancel();
      }
    });

    return controller.stream;
  }

  Future<void> updateLocation(
      String navigationId,
      LatLng location,
      double bearing,
      ) async {
    try {
      await _client.put(
        Uri.parse('$baseUrl/$navigationId/location'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'latitude': location.latitude,
          'longitude': location.longitude,
          'bearing': bearing,
        }),
      );
    } catch (e) {
      throw Exception('Error updating location: $e');
    }
  }

  Future<void> stopNavigation(String navigationId) async {
    try {
      await _client.delete(
        Uri.parse('$baseUrl/$navigationId'),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      throw Exception('Error stopping navigation: $e');
    }
  }
}