// lib/services/place_recommendation_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/recommended_place.dart';
import '../models/visit_history.dart';
import 'visit_history_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;
class PlaceRecommendationService {
  String? get foursquareApiKey => dotenv.dotenv.env['FOURSQUARE_API_KEY'];
  final VisitHistoryService _historyService = VisitHistoryService();

  // 경로 주변 장소 추천
  Future<List<RecommendedPlace>> getPlacesAlongRoute(
      dynamic route, {
        double radius = 500, // 기본 반경 500m
        List<String>? categories,
      }) async {
    if (foursquareApiKey == null) {
      throw Exception('Foursquare API key not found');
    }

    // 경로가 없거나 필요한 속성이 없는 경우 빈 리스트 반환
    if (route == null || !(route.points is List && route.samplePoints is List)) {
      return [];
    }

    final List<RecommendedPlace> recommendations = [];

    // 경로 샘플 포인트에서 장소 검색
    for (int i = 0; i < route.samplePoints.length; i++) {
      final point = route.samplePoints[i];

      try {
        // Foursquare API를 통해 주변 장소 검색
        final places = await _searchNearbyPlaces(
          point.latitude,
          point.longitude,
          radius: radius,
          categories: categories,
          limit: 3, // 각 포인트에서 최대 3곳만 검색
        );

        // 추천 이유 추가
        for (var place in places) {
          final double distanceFromRoute = _calculateDistanceToRoute(
            LatLng(place.latitude, place.longitude),
            route.points,
          );

          if (distanceFromRoute <= radius) {
            final reasonText = i == 0 ? '출발지 주변' :
            (i == route.samplePoints.length - 1 ? '도착지 주변' : '경로 주변');

            final RecommendedPlace recommendation = RecommendedPlace(
              id: place.id,
              name: place.name,
              latitude: place.latitude,
              longitude: place.longitude,
              address: place.address,
              category: place.category,
              rating: place.rating,
              photoUrl: place.photoUrl,
              distance: distanceFromRoute,
              reasonForRecommendation: reasonText,
            );

            // 중복 제거
            if (!recommendations.any((r) => r.id == recommendation.id)) {
              recommendations.add(recommendation);
            }
          }
        }
      } catch (e) {
        print('장소 검색 실패 (${point.latitude}, ${point.longitude}): $e');
      }
    }

    // 거리순으로 정렬
    recommendations.sort((a, b) => a.distance.compareTo(b.distance));

    return recommendations;
  }

  // 위치 기반 주변 장소 추천
// 변경 전: getNearbyPlaces 메서드 수정 (위치 기반 주변 장소 추천)
  Future<List<RecommendedPlace>> getNearbyPlaces(
      LatLng location, {
        double radius = 1000,
        String? category,
        int limit = 10,
      }) async {
    try {
      // category 매개변수를 categories 리스트로 변환
      List<String>? categories;
      if (category != null && category.isNotEmpty) {
        categories = [category];
      }

      // 이 부분 중요: 좌표 검증 추가
      print('현재 위치: ${location.latitude}, ${location.longitude}, 반경: ${radius}m');
      if (location.latitude == 0.0 || location.longitude == 0.0) {
        print('경고: 좌표가 0,0입니다. 유효하지 않은 위치입니다.');
        return [];
      }

      return _searchNearbyPlaces(
        location.latitude,
        location.longitude,
        radius: radius,
        categories: categories,
        limit: limit,
        strictDistance: true, // 거리 제한 엄격하게 적용 (추가된 매개변수)
      );
    } catch (e) {
      print('주변 장소 검색 오류: $e');
      return [];
    }
  }

  // 사용자 방문 기록 기반 추천
  Future<List<RecommendedPlace>> getRecommendationsBasedOnHistory(
      LatLng currentLocation, {
        int limit = 5,
        double radius = 5000, // 5km 반경
      }) async {
    try {
      // 자주 방문한 장소 가져오기
      final frequentPlaces = await _historyService.getFrequentlyVisitedPlaces();

      if (frequentPlaces.isEmpty) {
        return [];
      }

      // 자주 방문한 카테고리 분석
      final Map<String, int> categoryCount = {};
      for (var place in frequentPlaces) {
        categoryCount[place.category] = (categoryCount[place.category] ?? 0) + 1;
      }

      // 가장 많이 방문한 카테고리
      final preferredCategories = categoryCount.entries
          .sorted((a, b) => b.value.compareTo(a.value))
          .take(3)
          .map((e) => e.key)
          .toList();

      // 선호 카테고리 기반 주변 장소 검색
      final recommendations = await _searchNearbyPlaces(
        currentLocation.latitude,
        currentLocation.longitude,
        radius: radius,
        categories: preferredCategories,
        limit: limit,
      );

      // 이미 방문한 적 있는 장소는 제외
      final visited = frequentPlaces.map((p) => p.placeId).toSet();
      final filteredRecommendations = recommendations
          .where((p) => !visited.contains(p.id))
          .map((place) {
        final matchingCategories = preferredCategories
            .where((c) => c.toLowerCase() == place.category.toLowerCase())
            .toList();

        String reason = '';
        if (matchingCategories.isNotEmpty) {
          reason = '${matchingCategories.first} 카테고리를 자주 방문하셨습니다';
        } else {
          reason = '방문 기록을 기반으로 추천합니다';
        }

        return place.copyWith(
          reasonForRecommendation: reason,
        );
      })
          .toList();

      return filteredRecommendations;
    } catch (e) {
      print('방문 기록 기반 추천 실패: $e');
      return [];
    }
  }

  // 카테고리 기반 추천
  Future<List<RecommendedPlace>> getRecommendationsByCategory(
      String category,
      LatLng currentLocation, {
        int limit = 5,
        double radius = 5000, // 5km 반경
      }) async {
    try {
      final recommendations = await _searchNearbyPlaces(
        currentLocation.latitude,
        currentLocation.longitude,
        radius: radius,
        categories: [category],
        limit: limit,
      );

      return recommendations.map((place) {
        return place.copyWith(
          reasonForRecommendation: '$category 카테고리에서 추천합니다',
        );
      }).toList();
    } catch (e) {
      print('카테고리 기반 추천 실패: $e');
      return [];
    }
  }

// 변경 전: _searchNearbyPlaces 메서드 수정 (API 호출 및 결과 처리)
  Future<List<RecommendedPlace>> _searchNearbyPlaces(
      double lat,
      double lng, {
        double radius = 1000,
        List<String>? categories,
        int limit = 10,
        bool strictDistance = false, // 추가된 매개변수: 거리 제한 엄격히 적용 여부
      }) async {
    if (foursquareApiKey == null) {
      throw Exception('Foursquare API key not found');
    }

    // 좌표 유효성 검사 추가
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      print('잘못된 좌표: $lat, $lng - 유효 범위를 벗어납니다');
      return [];
    }

    String categoriesParam = '';
    if (categories != null && categories.isNotEmpty) {
      // Foursquare API에서 사용하는 카테고리 ID로 변환
      final categoryIds = _mapCategoriesToFoursquareIds(categories);
      if (categoryIds.isNotEmpty) {
        categoriesParam = '&categories=${categoryIds.join(',')}';
      }
    }

    // 반경을 정수로 변환 (API 요구사항)
    final int radiusInt = radius.toInt();

    final url = Uri.parse(
        'https://api.foursquare.com/v3/places/search'
            '?ll=$lat,$lng'
            '&radius=$radiusInt'
            '&limit=$limit'
            '$categoriesParam'
    );

    try {
      print('장소 검색 API 요청: $url');
      final response = await http.get(
        url,
        headers: {
          'Authorization': foursquareApiKey!,
          'Accept': 'application/json',
        },
      );

      print('API 응답 상태 코드: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('API 오류 응답: ${response.body}');
        return [];
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] == null || (data['results'] as List).isEmpty) {
          print('검색 결과 없음');
          return [];
        }

        print('검색된 장소 수: ${(data['results'] as List).length}');

        // 모든 검색 결과 파싱
        List<RecommendedPlace> allPlaces = [];
        for (var place in data['results']) {
          try {
            // 카테고리 가져오기
            final categories = place['categories'] as List? ?? [];
            final mainCategory = categories.isNotEmpty ? categories[0]['name'] ?? '기타' : '기타';

            // 좌표 가져오기 (geocodes가 기본, 없으면 location 사용)
            double latitude = 0.0;
            double longitude = 0.0;

            if (place['geocodes'] != null && place['geocodes']['main'] != null) {
              latitude = place['geocodes']['main']['latitude']?.toDouble() ?? 0.0;
              longitude = place['geocodes']['main']['longitude']?.toDouble() ?? 0.0;
            } else if (place['location'] != null) {
              latitude = place['location']['latitude']?.toDouble() ?? 0.0;
              longitude = place['location']['longitude']?.toDouble() ?? 0.0;
            }

            // 좌표가 없으면 건너뛰기
            if (latitude == 0.0 || longitude == 0.0) {
              print('경고: 장소 ${place['name']}의 좌표가 없습니다. 건너뜁니다.');
              continue;
            }

            // 주소 처리
            String address = '';
            if (place['location'] != null) {
              address = place['location']['formatted_address'] ??
                  place['location']['address'] ?? '';

              // 도시, 국가 등 추가 정보 포함
              String city = place['location']['locality'] ?? place['location']['city'] ?? '';
              String country = place['location']['country'] ?? '';

              if (city.isNotEmpty && !address.contains(city)) {
                address += address.isNotEmpty ? ', $city' : city;
              }
              if (country.isNotEmpty && !address.contains(country)) {
                address += address.isNotEmpty ? ', $country' : country;
              }

              if (address.isEmpty) {
                address = '주소 정보 없음';
              }
            } else {
              address = '주소 정보 없음';
            }

            // 거리 계산
            double distance = 0.0;
            if (place['distance'] != null) {
              distance = (place['distance'] as num).toDouble();
            } else {
              // API에서 거리 정보가 없으면 직접 계산
              distance = _calculateDistance(lat, lng, latitude, longitude);
            }

            print('장소: ${place['name']}, 거리: ${distance}m, 좌표: $latitude, $longitude');

            final recommendedPlace = RecommendedPlace(
              id: place['fsq_id'] ?? '',
              name: place['name'] ?? '이름 없음',
              latitude: latitude,
              longitude: longitude,
              address: address,
              category: mainCategory,
              rating: place['rating']?.toDouble() ?? 0.0,
              photoUrl: '',  // Foursquare API에서 사진은 별도 호출 필요
              distance: distance,
              reasonForRecommendation: '현재 위치에서 가까운 $mainCategory',
            );

            allPlaces.add(recommendedPlace);
          } catch (e) {
            print('장소 데이터 파싱 오류: $e');
          }
        }

        // 거리 제한 검증 및 필터링
        List<RecommendedPlace> filteredPlaces = [];

        if (strictDistance) {
          // 거리가 지정된 반경보다 1.5배까지만 허용 (약간의 여유 제공)
          final maxAllowedDistance = radius * 1.5;

          filteredPlaces = allPlaces.where((place) =>
          place.distance <= maxAllowedDistance
          ).toList();

          print('거리 필터링 적용 후 남은 장소: ${filteredPlaces.length}/${allPlaces.length}');

          // 필터링 후에도 결과가 없으면 최소한 가장 가까운 몇 개는 반환
          if (filteredPlaces.isEmpty && allPlaces.isNotEmpty) {
            // 거리순으로 정렬하고 최대 3개까지 반환
            allPlaces.sort((a, b) => a.distance.compareTo(b.distance));
            filteredPlaces = allPlaces.take(min(3, allPlaces.length)).toList();
            print('거리 필터링 조건 완화: 가장 가까운 ${filteredPlaces.length}개 장소 반환');
          }
        } else {
          filteredPlaces = allPlaces;
        }

        // 거리순으로 정렬
        filteredPlaces.sort((a, b) => a.distance.compareTo(b.distance));

        return filteredPlaces;
      }

      return [];
    } catch (e) {
      print('API 호출 또는 응답 처리 오류: $e');
      return [];
    }
  }

  // 카테고리 이름을 Foursquare 카테고리 ID로 매핑
  List<String> _mapCategoriesToFoursquareIds(List<String> categories) {
    // 실제 구현에서는 Foursquare 카테고리 ID로 매핑
    // 여기서는 간단한 예시만 제공
    Map<String, String> categoryToId = {
      '식당': '13065',
      '카페': '13032',
      '쇼핑': '17000',
      '관광': '16000',
      '문화': '10000',
      '엔터테인먼트': '10000',
      '호텔': '19014',
    };

    return categories
        .map((c) => categoryToId[c] ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  // 두 좌표 사이의 거리 계산 (미터 단위)
  double _calculateDistance(
      double lat1, double lon1,
      double lat2, double lon2
      ) {
    const double earthRadius = 6371000; // 미터
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // 좌표와 경로 사이의 최소 거리 계산
  double _calculateDistanceToRoute(LatLng point, List<LatLng> route) {
    if (route.isEmpty) return double.infinity;
    if (route.length == 1) return _calculateDistance(
        point.latitude, point.longitude,
        route[0].latitude, route[0].longitude
    );

    double minDistance = double.infinity;

    for (int i = 0; i < route.length - 1; i++) {
      final LatLng start = route[i];
      final LatLng end = route[i + 1];

      final double dist = _distanceToSegment(
          point.latitude, point.longitude,
          start.latitude, start.longitude,
          end.latitude, end.longitude
      );

      minDistance = min(minDistance, dist);
    }

    return minDistance;
  }

  // 좌표와 선분 사이의 거리 계산
  double _distanceToSegment(
      double px, double py,
      double x1, double y1,
      double x2, double y2
      ) {
    final double l2 = (pow(x2 - x1, 2) + pow(y2 - y1, 2)).toDouble();

    if (l2 == 0) {
      return _calculateDistance(px, py, x1, y1);
    }

    double t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / l2;
    t = max(0, min(1, t));

    final double projX = x1 + t * (x2 - x1);
    final double projY = y1 + t * (y2 - y1);

    return _calculateDistance(px, py, projX, projY);
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}

// RecommendedPlace 확장 메서드
extension RecommendedPlaceExtension on RecommendedPlace {
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

extension IterableExtension<T> on Iterable<T> {
  List<T> sorted(int Function(T a, T b) compare) {
    final list = toList();
    list.sort(compare);
    return list;
  }
}