// lib/services/subscription_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SubscriptionService {
  String get baseUrl {
    if (kIsWeb) {
      return dotenv.env['API_V1_URL'] ?? 'http://localhost:8081/api/v1';
    } else {
      return dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8081/api/v1';
    }
  }

  // 구독 상태 조회
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {
          'planType': 'FREE',
          'remaining': 3,
          'endDate': null
        };
      }

      final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

      final response = await http.get(
        Uri.parse('$baseUrl/subscriptions/status'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        print('구독 상태 조회 실패: ${response.body}');
        return {
          'planType': 'FREE',
          'remaining': 3,
          'endDate': null
        };
      }
    } catch (e) {
      print('구독 상태 조회 오류: $e');
      return {
        'planType': 'FREE',
        'remaining': 3,
        'endDate': null
      };
    }
  }

  // 구독 업데이트
  Future<bool> updateSubscription({
    required String productId,
    required String purchaseToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return false;
      }

      final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

      final response = await http.post(
        Uri.parse('$baseUrl/subscriptions/update'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'productId': productId,
          'purchaseToken': purchaseToken,
          'platform': 'android'
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('구독 업데이트 오류: $e');
      return false;
    }
  }

  // 구매 검증
  Future<bool> verifyPurchase({
    required String productId,
    required String purchaseToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return false;
      }

      final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

      final response = await http.post(
        Uri.parse('$baseUrl/subscriptions/verify'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'productId': productId,
          'purchaseToken': purchaseToken,
          'platform': 'android'
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('구매 검증 오류: $e');
      return false;
    }
  }
}