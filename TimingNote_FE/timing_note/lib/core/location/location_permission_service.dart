import 'package:permission_handler/permission_handler.dart';

/// 위치 권한을 한 곳에서 관리하는 서비스입니다.
///
/// 왜 분리했나?
/// - 화면/비즈니스 로직에서 권한 라이브러리(`permission_handler`)를 직접 다루면
///   코드가 흩어지고 테스트가 어려워집니다.
/// - 권한 확인/요청 정책을 이 클래스로 모아두면, 이후 정책 변경 시 수정 지점이 줄어듭니다.
class LocationPermissionService {
  /// 현재 `앱 사용 중` 위치 권한 상태를 조회합니다.
  Future<PermissionStatus> checkWhenInUse() async {
    return Permission.locationWhenInUse.status;
  }

  /// 현재 `항상 허용(백그라운드 포함)` 위치 권한 상태를 조회합니다.
  Future<PermissionStatus> checkAlways() async {
    return Permission.locationAlways.status;
  }

  /// 앱 사용 중 위치 권한을 요청합니다.
  Future<PermissionStatus> requestWhenInUse() async {
    return Permission.locationWhenInUse.request();
  }

  /// 백그라운드 geofence 감지를 위해 `항상 허용` 권한을 요청합니다.
  ///
  /// 주의:
  /// - iOS는 일반적으로 `When In Use`를 먼저 받은 뒤 `Always`를 요청해야 흐름이 자연스럽습니다.
  /// - Android도 OS 버전에 따라 백그라운드 권한 요청 UX가 다르게 동작할 수 있습니다.
  Future<PermissionStatus> requestAlways() async {
    return Permission.locationAlways.request();
  }

  /// 앱 사용 중 권한이 이미 허용되었는지 확인합니다.
  Future<bool> isWhenInUseGranted() async {
    final status = await checkWhenInUse();
    return status.isGranted;
  }

  /// 항상 허용 권한이 이미 허용되었는지 확인합니다.
  Future<bool> isAlwaysGranted() async {
    final status = await checkAlways();
    return status.isGranted;
  }
}
