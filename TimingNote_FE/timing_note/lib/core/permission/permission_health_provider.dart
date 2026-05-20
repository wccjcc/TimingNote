import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../location/location_permission_service.dart';
import '../notification/notification_permission_service.dart';

class PermissionHealth {
  const PermissionHealth({
    required this.locationServiceEnabled,
    required this.foregroundLocationGranted,
    required this.backgroundLocationGranted,
    required this.notificationGranted,
  });

  final bool locationServiceEnabled;
  final bool foregroundLocationGranted;
  final bool backgroundLocationGranted;
  final bool notificationGranted;

  bool get canUseCurrentLocation =>
      locationServiceEnabled && foregroundLocationGranted;

  bool get canUseGeofenceAlert =>
      canUseCurrentLocation && backgroundLocationGranted && notificationGranted;

  bool get hasWarning => !canUseGeofenceAlert;

  String get title {
    if (!locationServiceEnabled) {
      return '기기 위치를 켜면 더 정확해져요';
    }
    if (!foregroundLocationGranted) {
      return '위치 권한을 확인해 주세요';
    }
    if (!backgroundLocationGranted && !notificationGranted) {
      return '위치 알림 설정을 확인해 주세요';
    }
    if (!backgroundLocationGranted) {
      return '도착 알림은 항상 허용이 필요해요';
    }
    if (!notificationGranted) {
      return '알림 권한을 확인해 주세요';
    }
    return '권한 설정이 필요해요';
  }

  String get message {
    if (!locationServiceEnabled) {
      return '장소 추천과 도착 알림이 제한될 수 있어요';
    }
    if (!foregroundLocationGranted) {
      return '현재 위치 없이도 저장은 가능하지만 주변 후보 정확도가 낮아져요';
    }
    if (!backgroundLocationGranted && !notificationGranted) {
      return '백그라운드 위치와 알림을 허용하면 도착 알림을 받을 수 있어요';
    }
    if (!backgroundLocationGranted) {
      return '메모 저장은 가능하지만 앱을 닫으면 위치 알림이 제한될 수 있어요';
    }
    if (!notificationGranted) {
      return '장소 감지는 가능해도 푸시 알림을 받지 못할 수 있어요';
    }
    return '일부 기능이 제한될 수 있어요';
  }
}

final permissionBannerDismissedProvider = StateProvider<bool>((ref) => false);

final permissionHealthProvider = FutureProvider<PermissionHealth>((ref) async {
  if (kIsWeb) {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      final isGranted = permission == LocationPermission.whileInUse || 
                        permission == LocationPermission.always;
      
      return PermissionHealth(
        locationServiceEnabled: serviceEnabled,
        foregroundLocationGranted: isGranted,
        // 웹은 백그라운드 위치와 푸시 알림 개념이 모바일과 다르므로,
        // 포그라운드 위치만 허용되어 있으면 경고 배너를 숨기기 위해 true로 간주합니다.
        backgroundLocationGranted: isGranted,
        notificationGranted: isGranted,
      );
    } catch (e) {
      return const PermissionHealth(
        locationServiceEnabled: true,
        foregroundLocationGranted: false,
        backgroundLocationGranted: false,
        notificationGranted: false,
      );
    }
  }

  try {
    final locationPermission = LocationPermissionService();
    final notificationPermission = NotificationPermissionService();

    final results = await Future.wait<Object>([
      Geolocator.isLocationServiceEnabled(),
      locationPermission.checkWhenInUse(),
      locationPermission.checkAlways(),
      notificationPermission.check(),
    ]);

    final serviceEnabled = results[0] as bool;
    final whenInUse = results[1] as PermissionStatus;
    final always = results[2] as PermissionStatus;
    final notification = results[3] as PermissionStatus;

    return PermissionHealth(
      locationServiceEnabled: serviceEnabled,
      foregroundLocationGranted: whenInUse.isGranted,
      backgroundLocationGranted: always.isGranted,
      notificationGranted: notification.isGranted,
    );
  } catch (error) {
    debugPrint('Permission health check failed: $error');
    return const PermissionHealth(
      locationServiceEnabled: true,
      foregroundLocationGranted: false,
      backgroundLocationGranted: false,
      notificationGranted: false,
    );
  }
});
