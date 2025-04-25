// lib/services/place_recommendation_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/recommended_place.dart';
import '../models/visit_history.dart';
import '../models/category_data.dart';
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

  // 선호 카테고리 기반 추천 메서드 추가
  Future<List<RecommendedPlace>> getRecommendationsBasedOnPreferences(
      LatLng currentLocation, 
      List<String> preferredCategories, {
        int limit = 10,
        double radius = 5000,
      }) async {
    try {
      if (preferredCategories.isEmpty) {
        print('선호 카테고리가 없습니다. 일반 추천으로 대체합니다.');
        return getNearbyPlaces(currentLocation, limit: limit, radius: radius);
      }
      
      print('선호 카테고리 기반 추천: $preferredCategories');
      
      // 선호 카테고리를 Foursquare 카테고리 ID로 변환
      final List<String> foursquareIds = [];
      
      // CategoryData가 사용 가능한 경우 카테고리 ID를 카테고리 객체로 변환
      if (CategoryConstants.categories.isNotEmpty) {
        // 카테고리 ID를 카테고리 객체로 변환하여 foursquareId 추출
        for (String categoryId in preferredCategories) {
          final category = CategoryConstants.getCategoryById(categoryId);
          if (category != null && category.foursquareId.isNotEmpty) {
            if (!foursquareIds.contains(category.foursquareId)) {
              foursquareIds.add(category.foursquareId);
            }
          }
        }
      } else {
        // CategoryData가 사용 불가능한 경우 기존 매핑 사용
        for (String category in preferredCategories) {
          final foursquareId = _getCategoryId(category);
          if (foursquareId.isNotEmpty && !foursquareIds.contains(foursquareId)) {
            foursquareIds.add(foursquareId);
          }
        }
      }
      
      if (foursquareIds.isEmpty) {
        // 매핑 실패 시 카테고리 이름 그대로 사용
        foursquareIds.addAll(preferredCategories);
      }
      
      print('Foursquare 카테고리 ID: $foursquareIds');
      
      // 선호 카테고리별로 추천 장소 검색 (병렬 처리)
      final List<Future<List<RecommendedPlace>>> futures = [];
      
      // 너무 많은 요청을 방지하기 위해 카테고리 그룹화
      final int maxParallelRequests = 3;
      final int categoryPerRequest = (foursquareIds.length / maxParallelRequests).ceil();
      
      // 최대 3개의 병렬 요청으로 제한
      for (int i = 0; i < foursquareIds.length; i += categoryPerRequest) {
        final end = (i + categoryPerRequest < foursquareIds.length) 
            ? i + categoryPerRequest 
            : foursquareIds.length;
        
        // 각 그룹에 대한 검색 요청
        final subCategories = foursquareIds.sublist(i, end);
        print('검색 그룹 ${i ~/ categoryPerRequest + 1}: $subCategories');
        
        futures.add(
          _searchNearbyPlaces(
            currentLocation.latitude,
            currentLocation.longitude,
            radius: radius,
            categories: subCategories,
            limit: (limit ~/ maxParallelRequests) + (limit % maxParallelRequests),
            strictDistance: false,
          ),
        );
      }
      
      // 모든 검색 결과 수집
      final results = await Future.wait(futures);
      List<RecommendedPlace> allRecommendations = [];
      
      // 결과 병합
      for (var places in results) {
        allRecommendations.addAll(places);
      }
      
      // 이미 방문한 장소 제외
      final visitedPlaces = await _getVisitedPlaceIds();
      allRecommendations = allRecommendations
          .where((place) => !visitedPlaces.contains(place.id))
          .toList();
      
      // 카테고리 선호도에 따른 개인화된 이유 추가
      allRecommendations = _addPersonalizedReasons(
        allRecommendations, 
        preferredCategories,
      );
      
      // 거리순으로 정렬
      allRecommendations.sort((a, b) => a.distance.compareTo(b.distance));
      
      // 중복 제거 (같은 장소가 여러 카테고리에 해당될 수 있음)
      final Map<String, RecommendedPlace> uniqueRecommendations = {};
      for (var place in allRecommendations) {
        if (!uniqueRecommendations.containsKey(place.id)) {
          uniqueRecommendations[place.id] = place;
        }
      }
      
      print('총 ${uniqueRecommendations.length}개의 선호 카테고리 기반 추천 장소를 찾았습니다.');
      
      // 제한된 개수만 반환
      return uniqueRecommendations.values.toList()
        ..sort((a, b) => a.distance.compareTo(b.distance))
        ..take(limit).toList();
    } catch (e) {
      print('선호 카테고리 기반 추천 오류: $e');
      // 오류 발생 시 기본 추천으로 대체
      return getNearbyPlaces(currentLocation, limit: limit, radius: radius);
    }
  }

  // 방문한 장소 ID 목록 가져오기
  Future<Set<String>> _getVisitedPlaceIds() async {
    try {
      final visitHistories = await _historyService.getVisitHistories();
      return visitHistories.map((history) => history.placeId).toSet();
    } catch (e) {
      print('방문 이력 조회 오류: $e');
      return {};
    }
  }

  // 개인화된 추천 이유 추가
  List<RecommendedPlace> _addPersonalizedReasons(
    List<RecommendedPlace> places, 
    List<String> preferredCategories,
  ) {
    // CategoryData 객체 사용이 가능한 경우
    final bool canUseCategory = CategoryConstants.categories.isNotEmpty;
    
    // 선호 카테고리 객체 또는 이름 목록 생성
    final List<String> preferredCategoryNames = [];
    
    if (canUseCategory) {
      // CategoryData 클래스 사용 가능한 경우
      for (String categoryId in preferredCategories) {
        final category = CategoryConstants.getCategoryById(categoryId);
        if (category != null) {
          preferredCategoryNames.add(category.name);
        }
      }
    } else {
      // 직접 카테고리 이름 사용
      preferredCategoryNames.addAll(preferredCategories);
    }
    
    return places.map((place) {
      // 일치하는 카테고리 찾기
      String? matchingCategory;
      for (var categoryName in preferredCategoryNames) {
        if (place.category.toLowerCase().contains(categoryName.toLowerCase()) ||
            categoryName.toLowerCase().contains(place.category.toLowerCase())) {
          matchingCategory = categoryName;
          break;
        }
      }
      
      // 추천 이유 설정
      if (matchingCategory != null) {
        return place.copyWith(
          reasonForRecommendation: '선호하시는 "${matchingCategory}" 카테고리의 장소입니다',
        );
      } else {
        return place.copyWith(
          reasonForRecommendation: '선호하시는 카테고리를 기반으로 추천합니다',
        );
      }
    }).toList();
  }

  // 홈 화면 로딩 시 카테고리 기반 추천 메서드
  Future<List<RecommendedPlace>> getHomeScreenRecommendations(
      LatLng currentLocation, {
        int limit = 5,
        double radius = 5000,
        required List<String> preferredCategories,
      }) async {
    try {
      // 기본 순서: 1) 방문 기록 기반, 2) 선호 카테고리 기반, 3) 위치 기반
      List<RecommendedPlace> recommendations = [];
      
      // 방문 기록 기반 추천 시도 (최근 방문 기록이 있는 경우)
      final recentPlaces = await _historyService.getRecentlyVisitedPlaces(limit: 3);
      if (recentPlaces.isNotEmpty) {
        recommendations = await getRecommendationsBasedOnHistory(
          currentLocation,
          limit: limit,
          radius: radius,
        );
        
        if (recommendations.isNotEmpty) {
          print('방문 기록 기반 추천 사용');
          return recommendations;
        }
      }
      
      // 방문 기록 기반 추천이 없는 경우, 선호 카테고리 기반 추천 시도
      if (preferredCategories.isNotEmpty) {
        recommendations = await getRecommendationsBasedOnPreferences(
          currentLocation,
          preferredCategories,
          limit: limit,
          radius: radius,
        );
        
        if (recommendations.isNotEmpty) {
          print('선호 카테고리 기반 추천 사용');
          return recommendations;
        }
      }
      
      // 모두 실패한 경우, 위치 기반 추천
      print('위치 기반 추천 사용');
      return getNearbyPlaces(
        currentLocation,
        limit: limit,
        radius: radius,
      );
    } catch (e) {
      print('홈 화면 추천 오류: $e');
      // 오류 발생 시 기본 위치 기반 추천
      return getNearbyPlaces(
        currentLocation,
        limit: limit,
        radius: radius,
      );
    }
  }

  // _searchNearbyPlaces 메서드
  Future<List<RecommendedPlace>> _searchNearbyPlaces(
      double lat,
      double lng, {
        double radius = 1000,
        List<String>? categories,
        int limit = 10,
        bool strictDistance = false,
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

    // 필드 목록에 photos 추가
    final url = Uri.parse(
        'https://api.foursquare.com/v3/places/search'
            '?ll=$lat,$lng'
            '&radius=$radiusInt'
            '&limit=$limit'
            '$categoriesParam'
            '&fields=fsq_id,name,categories,geocodes,location,distance,photos'  // photos 필드 추가
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

            // 이미지 URL 추출 (새로 추가된 부분)
            String photoUrl = '';
            if (place['photos'] != null && (place['photos'] as List).isNotEmpty) {
              var photo = place['photos'][0];
              if (photo['prefix'] != null && photo['suffix'] != null) {
                // 이미지 크기 설정 (예: 300x300)
                photoUrl = '${photo['prefix']}300x300${photo['suffix']}';
              }
            }

            print('장소: ${place['name']}, 거리: ${distance}m, 좌표: $latitude, $longitude, 이미지: $photoUrl');

            final recommendedPlace = RecommendedPlace(
              id: place['fsq_id'] ?? '',
              name: place['name'] ?? '이름 없음',
              latitude: latitude,
              longitude: longitude,
              address: address,
              category: mainCategory,
              rating: place['rating']?.toDouble() ?? 0.0,
              photoUrl: photoUrl,  // 이미지 URL 설정
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

  // 개별 장소의 이미지를 가져오는 새로운 메서드 (필요한 경우 사용)
  Future<String?> getPlacePhoto(String placeId) async {
    if (foursquareApiKey == null) {
      throw Exception('Foursquare API key not found');
    }

    final url = Uri.parse('https://api.foursquare.com/v3/places/$placeId/photos');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': foursquareApiKey!,
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          var photo = data[0];
          if (photo['prefix'] != null && photo['suffix'] != null) {
            return '${photo['prefix']}300x300${photo['suffix']}';
          }
        }
      } else {
        print('장소 이미지 API 오류: ${response.statusCode} - ${response.body}');
      }
      
      return null;
    } catch (e) {
      print('장소 이미지 가져오기 오류: $e');
      return null;
    }
  }

  // 카테고리 이름을 Foursquare 카테고리 ID로 매핑
  List<String> _mapCategoriesToFoursquareIds(List<String> categories) {
    // 확장된 카테고리 체계가 로드되었는지 확인
    if (CategoryConstants.categories.isNotEmpty) {
      // CategoryData 사용 가능할 경우, 이를 우선 사용
      List<String> foursquareIds = [];
      
      for (String category in categories) {
        // 카테고리 ID로 직접 조회 시도
        final categoryData = CategoryConstants.getCategoryById(category);
        if (categoryData != null && categoryData.foursquareId.isNotEmpty) {
          foursquareIds.add(categoryData.foursquareId);
          continue;
        }
        
        // 실패하면 카테고리 이름으로 조회 시도
        final categoryByName = CategoryConstants.getCategoryByName(category);
        if (categoryByName != null && categoryByName.foursquareId.isNotEmpty) {
          foursquareIds.add(categoryByName.foursquareId);
          continue;
        }
        
        // 둘 다 실패하면 기존 매핑 시도
        final foursquareId = _getCategoryId(category);
        if (foursquareId.isNotEmpty) {
          foursquareIds.add(foursquareId);
        }
      }
      
      return foursquareIds.where((id) => id.isNotEmpty).toList();
    } else {
      // 기존 매핑 사용
      return categories
          .map((c) => _getCategoryId(c))
          .where((id) => id.isNotEmpty)
          .toList();
    }
  }

  // 카테고리 문자열을 Foursquare ID로 변환하는 간단한 헬퍼 메서드
  String _getCategoryId(String category) {
    // 카테고리 이름 표준화 (소문자, 공백 제거)
    final String normalizedCategory = category.toLowerCase().trim();
    
    // 기본 매핑 사전
    final Map<String, String> categoryToId = {
      '식당': '13065',
      '음식점': '13065',
      '레스토랑': '13065',
      '한식': '13072',
      '중식': '13073',
      '일식': '13080',
      '양식': '13076',
      '패스트푸드': '13145',
      
      '카페': '13032',
      '커피': '13032',
      '디저트': '13040',
      '베이커리': '13041',
      '티룸': '13034',
      
      '쇼핑': '17000',
      '쇼핑몰': '17015',
      '패션': '17020',
      '전자제품': '17061',
      '시장': '17047',
      '마트': '17069',
      '백화점': '17069',
      
      '관광': '16000',
      '명소': '16000',
      '공원': '16010',
      '등산': '16019',
      '해변': '16049',
      '산책로': '16032',
      
      '문화': '10000',
      '박물관': '10027',
      '미술관': '10022',
      '역사': '10047',
      
      '엔터테인먼트': '10000',
      '영화관': '10024',
      '공연장': '10028',
      '놀이공원': '10001',
      '게임': '10022',
      
      '호텔': '19014',
      '숙소': '19014',
      '게스트하우스': '19011',
      
      '바': '14003',
      '클럽': '14004',
      '나이트라이프': '14000',
      
      '병원': '15014',
      '약국': '15035',
      '피트니스': '15013',
      '헬스': '15013',
      
      '교육': '12000',
      '도서관': '12009',
      '서점': '17038',
      '학교': '12012',
      
      '대중교통': '19000',
      '지하철': '19026',
      '버스': '19021',
      '주차장': '19033',
      '주유소': '19007',
    };
    
    // 키워드 기반 매칭 (완전 일치)
    if (categoryToId.containsKey(normalizedCategory)) {
      return categoryToId[normalizedCategory]!;
    }
    
    // 부분 매칭 (포함)
    for (var entry in categoryToId.entries) {
      if (normalizedCategory.contains(entry.key) || 
          entry.key.contains(normalizedCategory)) {
        return entry.value;
      }
    }
    
    // 매치를 찾지 못한 경우 빈 문자열 반환
    return '';
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