import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/location/location_permission_service.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/notification/local_notification_service.dart';
import '../../../core/notification/notification_permission_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _showCurrentLocationNotification(BuildContext context) async {
    final notificationPermissionService = NotificationPermissionService();
    final locationPermissionService = LocationPermissionService();
    final locationService = LocationService(locationPermissionService);
    final localNotificationService = LocalNotificationService();

    try {
      // 1) 알림 권한 확인/요청
      var notificationGranted = await notificationPermissionService.isGranted();
      if (!notificationGranted) {
        final notificationStatus = await notificationPermissionService.request();
        notificationGranted = notificationStatus.isGranted;
      }
      if (!notificationGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('알림 권한이 필요합니다.')),
          );
        }
        return;
      }

      // 2) 위치 권한 확인/요청
      var locationGranted = await locationPermissionService.isGranted();
      if (!locationGranted) {
        final locationStatus =
            await locationPermissionService.requestWhenInUse();
        locationGranted = locationStatus.isGranted;
      }
      if (!locationGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 권한이 필요합니다.')),
          );
        }
        return;
      }

      // 3) 현재 위치 1회 조회
      final position = await locationService.getCurrentPosition();

      // 4) 좌표를 로컬 알림으로 표시
      await localNotificationService.showTestNotification(
        title: '현재 위치 좌표',
        body:
            'lat: ${position.latitude.toStringAsFixed(6)}, lng: ${position.longitude.toStringAsFixed(6)}',
      );
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치/알림 테스트 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _showCurrentLocationNotification(context),
          child: const Text('현재 위치 알림 테스트'),
        ),
      ),
    );
  }
}
