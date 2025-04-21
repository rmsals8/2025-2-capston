// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// 현재 위치를 가져옵니다.
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 비활성화되어 있습니다.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.');
    }

    // 위치 정보 반환
    return await Geolocator.getCurrentPosition();
  }

  /// 두 위치 간의 거리를 계산합니다 (미터 단위).
  double calculateDistance(double startLatitude, double startLongitude,
      double endLatitude, double endLongitude) {
    return Geolocator.distanceBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude
    );
  }

  /// 현재 위치가 특정 위치와 지정된 반경(미터) 내에 있는지 확인합니다.
  Future<bool> isWithinRadius(double latitude, double longitude, double radius) async {
    try {
      final currentPosition = await getCurrentLocation();
      final distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          latitude,
          longitude
      );

      return distance <= radius;
    } catch (e) {
      print('위치 확인 오류: $e');
      return false;
    }
  }
}