import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SubscriptionService {
  String get baseUrl {
    if (kIsWeb) {
      return dotenv.env['API_V1_URL'] ?? 'http://localhost:8081/api/v1';
    } else {
      return dotenv.env['API_V1_URL'] ?? 'http://10.0.2.2:8081/api/v1';
    }
  }

  // 구독 상태 조회 메서드
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final userId = await _getUserId();

      if (token == null || token.isEmpty || userId == null) {
        print('토큰 또는 사용자 ID가 없습니다.');
        return {
          'planType': 'FREE',
          'remaining': 3,
          'endDate': null
        };
      }

      final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

      // 구독 정보 조회 API 호출
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/tier'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        // 사용량 정보 조회 API 호출
        final usageResponse = await http.get(
          Uri.parse('$baseUrl/usage/remaining/$userId'),
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/json',
          },
        );

        int remaining = 3; // 기본값
        if (usageResponse.statusCode == 200) {
          final usageData = json.decode(utf8.decode(usageResponse.bodyBytes));
          remaining = usageData['remaining'] ?? 3;
        }

        return {
          'planType': data['planType'] ?? 'FREE',
          'remaining': remaining,
          'endDate': data['endDate'],
          'status': data['status'] ?? 'ACTIVE'
        };
      } else {
        print('구독 정보 조회 실패: ${response.body}');
        return {
          'planType': 'FREE',
          'remaining': 3,
          'endDate': null
        };
      }
    } catch (e) {
      print('구독 정보 조회 오류: $e');
      return {
        'planType': 'FREE',
        'remaining': 3,
        'endDate': null
      };
    }
  }

  // 구독 정보 업데이트 메서드 (구매 완료 후 호출)
  Future<bool> updateSubscription({
    required String productId,
    required String purchaseToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final userId = await _getUserId();

      if (token == null || token.isEmpty || userId == null) {
        print('토큰 또는 사용자 ID가 없습니다.');
        return false;
      }

      final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

      // 구독 타입 결정 (월간 또는 연간)
      final bool isMonthly = productId.contains('monthly');
      final subscriptionPeriod = isMonthly ? 'MONTHLY' : 'YEARLY';

      // 구독 업데이트 API 호출
      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/subscription'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'planType': 'PREMIUM',
          'period': subscriptionPeriod,
          'purchaseToken': purchaseToken,
          'productId': productId
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('구독 정보 업데이트 성공');
        return true;
      } else {
        print('구독 정보 업데이트 실패: ${response.body}');
        return false;
      }
    } catch (e) {
      print('구독 정보 업데이트 오류: $e');
      return false;
    }
  }

  // 구독 정보 확인 (사용량 체크)
  Future<bool> checkUsageLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final userId = await _getUserId();

      if (token == null || token.isEmpty || userId == null) {
        print('토큰 또는 사용자 ID가 없습니다.');
        return false;
      }

      final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

      // 사용량 체크 API 호출
      final response = await http.get(
        Uri.parse('$baseUrl/usage/check/$userId'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['canUse'] ?? false;
      } else {
        print('사용량 체크 실패: ${response.body}');
        return false;
      }
    } catch (e) {
      print('사용량 체크 오류: $e');
      return false;
    }
  }

  // 사용량 증가 메서드 (서비스 사용 시 호출)
  Future<bool> incrementUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final userId = await _getUserId();

      if (token == null || token.isEmpty || userId == null) {
        print('토큰 또는 사용자 ID가 없습니다.');
        return false;
      }

      final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

      // 사용량 증가 API 호출
      final response = await http.post(
        Uri.parse('$baseUrl/usage/increment/$userId'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['success'] ?? false;
      } else {
        print('사용량 증가 실패: ${response.body}');
        return false;
      }
    } catch (e) {
      print('사용량 증가 오류: $e');
      return false;
    }
  }

  // 사용자 ID 가져오기
  Future<String?> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');

      if (userId == null || userId.isEmpty) {
        // 사용자 ID가 없는 경우 사용자 정보 API로 조회
        final token = prefs.getString('access_token');
        if (token != null && token.isNotEmpty) {
          final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

          try {
            final response = await http.get(
              Uri.parse('$baseUrl/users/me'),
              headers: {
                'Authorization': authHeader,
                'Content-Type': 'application/json',
              },
            );

            if (response.statusCode == 200) {
              final userData = json.decode(utf8.decode(response.bodyBytes));
              userId = userData['id']?.toString();

              if (userId != null) {
                // 사용자 ID 저장
                await prefs.setString('user_id', userId);
              }
            }
          } catch (e) {
            print('사용자 정보 조회 오류: $e');
          }
        }
      }

      return userId;
    } catch (e) {
      print('사용자 ID 가져오기 오류: $e');
      return null;
    }
  }
}