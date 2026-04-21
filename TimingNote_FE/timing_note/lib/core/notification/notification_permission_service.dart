import 'package:permission_handler/permission_handler.dart';

/// 알림 권한 확인/요청 서비스
class NotificationPermissionService {
  /// 현재 알림 권한 상태 확인
  Future<PermissionStatus> check() async {
    return Permission.notification.status;
  }

  /// 알림 권한 요청
  Future<PermissionStatus> request() async {
    return Permission.notification.request();
  }

  /// 알림 권한 허용 여부(bool) 확인
  Future<bool> isGranted() async {
    final status = await check();
    return status.isGranted;
  }

  /// 권한이 완전 거부(permanentlyDenied)인지 확인
  /// iOS에서는 설정 앱 이동 유도할 때 사용
  Future<bool> isPermanentlyDenied() async {
    final status = await check();
    return status.isPermanentlyDenied;
  }

  /// 시스템 설정 화면 열기
  Future<bool> openSettings() async {
    return openAppSettings();
  }
}
