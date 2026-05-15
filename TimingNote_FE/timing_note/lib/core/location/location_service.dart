import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
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

  /// 현재 위치 조회.
  ///
  /// [fastMode] true (= 표시용):
  /// - iOS가 보관 중인 마지막 위치(`getLastKnownPosition`)를 먼저 시도 → 콜드 스타트 회피
  /// - 캐시 미스면 medium 정확도로 fallback (정확도는 항상 ~100m 이상 보장)
  ///
  /// [fastMode] false (= 알림 트리거 등):
  /// - 캐시 무시하고 medium 정확도로 새 측정
  ///
  /// 두 모드 모두 정확도는 [LocationAccuracy.medium](~100m) 이상을 보장한다.
  /// 차이는 "디바이스 캐시 우선 사용 여부"뿐.
  Future<Position> getCurrentPosition({bool fastMode = false}) async {
    // Web은 permission_handler 미지원 → 권한 체크 건너뛰고 geolocator가 브라우저에 직접 권한 prompt를 띄우게 한다.
    // HTTPS 또는 localhost 컨텍스트가 아니면 브라우저가 위치 API 자체를 차단함.
    if (kIsWeb) {
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _kFixTimeout,
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

    if (fastMode) {
      // 마지막 캐시된 위치 — 백그라운드 지오펜스/다른 앱/이전 세션이 잡아둔 결과.
      // 너무 오래된 캐시는 사용자가 그 사이 이동했을 수 있어 stale 위험 — 5분 신선도 필터.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final age = DateTime.now().difference(last.timestamp);
        if (age < _kDeviceCacheFreshness) {
          debugPrint('[GPS] device-lastKnown HIT | age=${age.inSeconds}s '
              '(freshness=${_kDeviceCacheFreshness.inMinutes}m) | '
              'lat=${last.latitude.toStringAsFixed(6)} '
              'lng=${last.longitude.toStringAsFixed(6)} | '
              'measuredAt=${last.timestamp.toIso8601String()}');
          return last;
        }
        debugPrint('[GPS] device-lastKnown STALE | age=${age.inSeconds}s '
            '> freshness=${_kDeviceCacheFreshness.inMinutes}m → fresh measure');
      } else {
        debugPrint('[GPS] device-lastKnown NULL  | → fresh measure');
      }
      // 캐시 없음 또는 stale → medium 정확도로 정상 측정
    }

    debugPrint('[GPS] fresh measure start  | accuracy=medium, timeLimit=${_kFixTimeout.inSeconds}s');
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: _kFixTimeout,
      ),
    );
    debugPrint('[GPS] fresh measure done   | '
        'lat=${pos.latitude.toStringAsFixed(6)} '
        'lng=${pos.longitude.toStringAsFixed(6)} | '
        'measuredAt=${pos.timestamp.toIso8601String()}');
    return pos;
  }

  /// 디바이스 캐시(getLastKnownPosition)의 신선도 한계.
  /// 도보 5분=~400m, 차량 5분=~5km. 그 이상 오래된 캐시는 거리 라벨 stale 위험.
  static const Duration _kDeviceCacheFreshness = Duration(minutes: 5);

  /// GPS lock timeout. 차폐 환경(지하/실내 깊숙한 곳)/콜드 스타트 stall에서 무한 대기 방지.
  /// 초과 시 TimeoutException → 호출자가 catch로 null fallback → BE는 좌표 optional로 정상 처리.
  static const Duration _kFixTimeout = Duration(seconds: 10);
}
