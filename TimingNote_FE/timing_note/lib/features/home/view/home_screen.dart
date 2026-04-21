import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/geofence/geofence_runtime.dart';
import '../../../core/location/location_permission_service.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/notification/local_notification_service.dart';
import '../../../core/notification/notification_permission_service.dart';

/// 앱 home screen 
///
/// 이 화면의 핵심 역할
/// 1) 화면 진입 시 geofence 모니터링을 시작
/// 2) 현재 위치를 조회해 로컬 알림으로 보여주는 테스트 기능을 제공
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// geofence 모니터링이 이미 시작되었는지 표시하는 상태값
  /// 중복 시작 호출을 막기 위해 사용
  bool _monitoringStarted = false;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 렌더링 이후에 모니터링 시작을 시도합니다.
    // initState 즉시 setState/스낵바를 건드리는 타이밍 이슈를 피하기 위함
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startGeofenceMonitoring();
    });
  }

  /// geofence 모니터링 시작 함수
  ///
  /// 동작 순서
  /// 1) 이미 시작된 경우 즉시 반환
  /// 2) runtime.start() 호출(내부에서 권한 확인 + 네이티브 등록 + 이벤트 구독)
  /// 3) 성공 시 UI 상태/스낵바 갱신
  /// 4) 실패 시 예외 메시지 출력
  Future<void> _startGeofenceMonitoring() async {
    // 중복 클릭/중복 호출 방지
    if (_monitoringStarted) {
      return;
    }

    try {
      // geofence 전체 파이프라인 시작
      await ref.read(geofenceRuntimeProvider).start();

      // await 이후 화면이 dispose 되었을 수 있으므로 mounted 체크
      if (!mounted) {
        return;
      }

      // 버튼 문구를 "활성화됨" 상태로 바꾸기 위한 상태 갱신
      setState(() {
        _monitoringStarted = true;
      });

      // 사용자 피드백
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geofence monitoring started.')),
      );
    } on ApiException catch (e) {
      // 서버/권한/네트워크 계층에서 의도적으로 throw한 앱 공통 예외
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      // 예상하지 못한 예외 fallback
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start geofence monitoring.')),
      );
    }
  }

  Future<void> _showCurrentLocationNotification(BuildContext context) async {
    // 화면 테스트용으로 필요한 서비스 객체를 생성합니다.
    // (현재 구조에서는 간단히 함수 내부에서 생성)
    final notificationPermissionService = NotificationPermissionService();
    final locationPermissionService = LocationPermissionService();
    final locationService = LocationService(locationPermissionService);
    final localNotificationService = LocalNotificationService();

    try {
      // 1) 알림 권한 확인 -> 없으면 요청
      var notificationGranted = await notificationPermissionService.isGranted();
      if (!notificationGranted) {
        await notificationPermissionService.request();
        notificationGranted = await notificationPermissionService.isGranted();
      }

      // 권한이 끝내 거부되면 더 진행하지 않고 안내 후 종료
      if (!notificationGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission denied.')),
          );
        }
        return;
      }

      // 2) 위치 권한(앱 사용 중) 확인 -> 없으면 요청
      var locationGranted =
          await locationPermissionService.isWhenInUseGranted();
      if (!locationGranted) {
        await locationPermissionService.requestWhenInUse();
        locationGranted =
            await locationPermissionService.isWhenInUseGranted();
      }

      // 권한이 끝내 거부되면 위치 조회를 중단
      if (!locationGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return;
      }

      // 3) 현재 좌표 조회
      final position = await locationService.getCurrentPosition();

      // 4) 좌표를 로컬 알림으로 표시
      await localNotificationService.showTestNotification(
        title: 'Current location',
        body:
            'lat: ${position.latitude.toStringAsFixed(6)}, lng: ${position.longitude.toStringAsFixed(6)}',
      );
    } on ApiException catch (e) {
      // 위치 서비스 OFF/권한 문제 등 앱 공통 예외 처리
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      // 그 외 알 수 없는 오류 처리
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to read location or show notification.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // geofence 모니터링 시작 버튼
            ElevatedButton(
              onPressed: _startGeofenceMonitoring,
              child: Text(
                _monitoringStarted
                    ? 'Geofence monitoring active'
                    : 'Start geofence monitoring',
              ),
            ),
            const SizedBox(height: 12),

            // 현재 위치 + 로컬 알림 테스트 버튼
            ElevatedButton(
              onPressed: () => _showCurrentLocationNotification(context),
              child: const Text('Show current location notification'),
            ),
          ],
        ),
      ),
    );
  }
}
