import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

import '../network/api_exception.dart';
import 'location_permission_service.dart';

/// 현재 위치를 조회하는 서비스입니다.
///
/// geofence 자체는 네이티브에서 처리하더라도,
/// 화면 테스트/진단(현재 좌표 확인) 시에는 이 서비스가 계속 유용합니다.
class LocationService {
  final LocationPermissionService _permissionService;

  LocationService(this._permissionService);

  Future<Position> getCurrentPosition() async {
    // Web은 permission_handler 미지원 → 권한 체크 건너뛰고 geolocator가 브라우저에 직접 권한 prompt를 띄우게 한다.
    // HTTPS 또는 localhost 컨텍스트가 아니면 브라우저가 위치 API 자체를 차단함.
    if (kIsWeb) {
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
    }

    final granted = await _permissionService.isWhenInUseGranted();
    if (!granted) {
      throw const ApiException(
        code: 'LOCATION_PERMISSION_DENIED',
        message: '위치 권한이 허용되지 않았습니다.',
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const ApiException(
        code: 'LOCATION_SERVICE_DISABLED',
        message: '기기 위치 서비스가 꺼져 있습니다.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
  }
}
