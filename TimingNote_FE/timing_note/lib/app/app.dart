import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../core/geofence/geofence_runtime.dart';
import '../core/notification/fcm_token_service.dart';
import '../core/notification/push_action_bridge.dart';
import '../core/location/location_permission_service.dart';
import '../core/location/location_service.dart';
import '../features/notification/service/notification_service.dart';
import 'router.dart';
import 'theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

/// 앱 루트에서 lifecycle을 감시해 geofence 런타임을 제어합니다.
///
/// 정책:
/// - foreground(resumed): geofenceRuntime.start() 보장 + syncSlots() 강제 1회
/// - background/paused: geofenceRuntime.stop()으로 SSE/감시 리소스 정리
class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  static final Logger _logger = Logger();

  late final Future<void> _bootstrapFuture;
  final PushActionBridge _pushActionBridge = PushActionBridge();
  StreamSubscription<Map<String, String>>? _pushActionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _bootstrapFuture = Future<void>.microtask(() async {
      try {
        // FCM 토큰 초기화는 앱 시작 시점에 1회 수행합니다.
        await ref.read(fcmTokenServiceProvider).initialize();
        await _pushActionBridge.initialize();
        _pushActionSubscription = _pushActionBridge.events.listen(_handlePushActionEvent);
      } catch (e) {
        debugPrint('Bootstrap skipped: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final subscription = _pushActionSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // lifecycle 콜백은 동기 메서드이므로, 내부에서 비동기 작업을 분리 실행합니다.
    unawaited(_handleLifecycle(state));
  }

  /// 앱 상태 전환에 맞춰 geofence 런타임을 제어합니다.
  Future<void> _handleLifecycle(AppLifecycleState state) async {
    // 웹에서는 geofence/SSE 런타임을 사용하지 않으므로 lifecycle 제어를 스킵합니다.
    if (kIsWeb) {
      return;
    }

    final runtime = ref.read(geofenceRuntimeProvider);

    switch (state) {
      case AppLifecycleState.resumed:
        // foreground 복귀 시:
        // 1) 런타임이 꺼져있다면 다시 시작
        // 2) 슬롯 강제 동기화 1회로 background 동안의 상태 차이를 복구
        await runtime.start();
        await runtime.syncSlots();
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // background 전환 시에는 geofence 감시는 유지하고,
        // SSE 실시간 동기화만 중지합니다.
        //
        // 중요:
        // - detached에서도 runtime.stop()을 호출하지 않습니다.
        // - stop()은 내부에서 clearGeofences()를 수행하므로,
        //   앱 종료 직전 geofence 등록이 해제되어 "앱이 꺼져도 감시 유지" 요구와 충돌합니다.
        // - 따라서 lifecycle 경로에서는 일관되게 "SSE만 중지" 정책을 사용합니다.
        await runtime.pauseRealtimeSync();
        break;
    }
  }

  /// iOS 푸시 액션 버튼 탭 이벤트를 처리합니다.
  ///
  /// 처리 규칙:
  /// - COMPLETE   -> NOTI-02 actionType=COMPLETE
  /// - SNOOZE_60  -> NOTI-02 actionType=SNOOZE, snoozeMinutes=60
  /// - geofence 슬롯 반영은 백엔드 outbox->consumer->SSE signal 경로에 위임
  Future<void> _handlePushActionEvent(Map<String, String> event) async {
    final actionId = event['actionId'] ?? '';
    final notificationId = int.tryParse(event['notificationId'] ?? '');
    if (notificationId == null) {
      _logger.w('[PUSH_ACTION_SKIP] invalid notificationId event=$event');
      return;
    }

    final notificationService = ref.read(notificationServiceProvider);
    try {
      // 액션 유형과 무관하게 현재 위치/방향을 best-effort로 수집합니다.
      // 실패 시 null을 전송하고 액션은 계속 진행합니다.
      double? latitude;
      double? longitude;
      double? course;
      try {
        final locationService = LocationService(LocationPermissionService());
        final position = await locationService.getCurrentPosition();
        latitude = position.latitude;
        longitude = position.longitude;
        if (position.heading.isFinite && position.heading >= 0) {
          course = position.heading;
        }
      } catch (e) {
        _logger.w('[PUSH_ACTION_LOCATION_SKIP] action without location: $e');
      }

      if (actionId == 'COMPLETE') {
        await notificationService.applyAction(
          notificationId: notificationId,
          actionType: 'COMPLETE',
          latitude: latitude,
          longitude: longitude,
          course: course,
        );
      } else if (actionId == 'SNOOZE_60') {
        await notificationService.applyAction(
          notificationId: notificationId,
          actionType: 'SNOOZE',
          snoozeMinutes: 60,
          latitude: latitude,
          longitude: longitude,
          course: course,
        );
      } else {
        _logger.w('[PUSH_ACTION_SKIP] unsupported actionId=$actionId');
        return;
      }
    } catch (e, st) {
      _logger.e('[PUSH_ACTION_ERROR] failed action handling', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '앱 초기화 중 오류가 발생했습니다.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        final router = ref.watch(appRouterProvider);

        return MaterialApp.router(
          title: 'Timing Note',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          routerConfig: router,
        );
      },
    );
  }
}

