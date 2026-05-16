import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// 알림 권한 확인/요청 서비스
class NotificationPermissionService {
  static Future<PermissionStatus>? _requestInFlight;

  /// 현재 알림 권한 상태 확인
  Future<PermissionStatus> check() async {
    return Permission.notification.status;
  }

  /// 알림 권한 요청
  ///
  /// iOS에서는 권한 팝업이 이미 떠 있는 동안 다시 요청하면
  /// ERROR_ALREADY_REQUESTING_PERMISSIONS 예외가 발생할 수 있습니다.
  /// 그래서 앱 시작/resume 등 여러 진입점에서 동시에 호출돼도 실제 요청은 1개만 수행합니다.
  Future<PermissionStatus> request() async {
    final runningRequest = _requestInFlight;
    if (runningRequest != null) {
      return runningRequest;
    }

    final request = _requestIfNotDetermined();
    _requestInFlight = request;

    try {
      return await request;
    } finally {
      _requestInFlight = null;
    }
  }

  Future<PermissionStatus> _requestIfNotDetermined() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }

    return check();
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

final notificationPermissionServiceProvider =
    Provider<NotificationPermissionService>((ref) {
      return NotificationPermissionService();
    });
