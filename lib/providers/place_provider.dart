import 'package:flutter/foundation.dart';
import 'package:trip_helper/models/place.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PlaceProvider with ChangeNotifier {
  List<Place> _recentPlaces = [];
  List<Place> _recommendedPlaces = [];
  List<Place> _wishlistPlaces = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Place> get recentPlaces => _recentPlaces;
  List<Place> get recommendedPlaces => _recommendedPlaces;
  List<Place> get wishlistPlaces => _wishlistPlaces;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 최근 방문 장소 로드
  Future<void> loadRecentPlaces() async {
    try {
      _setLoading(true);
      // TODO: API 호출로 변경
      // 임시 데이터
      _recentPlaces = [
        Place(
          id: '1',
          name: '코엑스몰',
          type: '쇼핑',
          visitDate: DateTime.now().subtract(const Duration(days: 2)),
          latitude: 37.5115557,
          longitude: 127.0595261,
        ),
        Place(
          id: '2',
          name: '스타벅스 강남점',
          type: '카페',
          visitDate: DateTime.now().subtract(const Duration(days: 4)),
          latitude: 37.4979462,
          longitude: 127.0276156,
        ),
      ];
      _saveToLocal('recent_places', _recentPlaces);
      notifyListeners();
    } catch (e) {
      _setError('최근 방문 장소를 불러오는데 실패했습니다.');
    } finally {
      _setLoading(false);
    }
  }

  // 추천 장소 로드
  Future<void> loadRecommendedPlaces() async {
    try {
      _setLoading(true);
      // TODO: API 호출로 변경
      _recommendedPlaces = [
        Place(
          id: '3',
          name: '경복궁',
          type: '관광',
          latitude: 37.579617,
          longitude: 126.977041,
        ),
        Place(
          id: '4',
          name: '롯데월드',
          type: '놀이공원',
          latitude: 37.511397,
          longitude: 127.098164,
        ),
      ];
      _saveToLocal('recommended_places', _recommendedPlaces);
      notifyListeners();
    } catch (e) {
      _setError('추천 장소를 불러오는데 실패했습니다.');
    } finally {
      _setLoading(false);
    }
  }

  // 위시리스트 로드
  Future<void> loadWishlistPlaces() async {
    try {
      _setLoading(true);
      // TODO: API 호출로 변경
      _wishlistPlaces = [
        Place(
          id: '5',
          name: '남산타워',
          type: '관광',
          latitude: 37.551348,
          longitude: 126.988436,
        ),
      ];
      _saveToLocal('wishlist_places', _wishlistPlaces);
      notifyListeners();
    } catch (e) {
      _setError('위시리스트를 불러오는데 실패했습니다.');
    } finally {
      _setLoading(false);
    }
  }

  // 위시리스트에 장소 추가
  Future<void> addToWishlist(Place place) async {
    try {
      if (!_wishlistPlaces.any((p) => p.id == place.id)) {
        _wishlistPlaces.add(place);
        await _saveToLocal('wishlist_places', _wishlistPlaces);
        notifyListeners();
      }
    } catch (e) {
      _setError('위시리스트에 추가하는데 실패했습니다.');
    }
  }

  // 위시리스트에서 장소 제거
  Future<void> removeFromWishlist(String placeId) async {
    try {
      _wishlistPlaces.removeWhere((p) => p.id == placeId);
      await _saveToLocal('wishlist_places', _wishlistPlaces);
      notifyListeners();
    } catch (e) {
      _setError('위시리스트에서 제거하는데 실패했습니다.');
    }
  }

  // 로컬 저장소에 데이터 저장
  Future<void> _saveToLocal(String key, List<Place> places) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final placesJson = places.map((place) => place.toJson()).toList();
      await prefs.setString(key, jsonEncode(placesJson));
    } catch (e) {
      _setError('데이터 저장에 실패했습니다.');
    }
  }

  // 로컬 저장소에서 데이터 로드
  Future<List<Place>> _loadFromLocal(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? placesString = prefs.getString(key);
      if (placesString != null) {
        final List<dynamic> placesJson = jsonDecode(placesString);
        return placesJson.map((json) => Place.fromJson(json)).toList();
      }
    } catch (e) {
      _setError('저장된 데이터를 불러오는데 실패했습니다.');
    }
    return [];
  }

  // 상태 변경 헬퍼 메서드
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}