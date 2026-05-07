import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

import '../core/geofence/geofence_runtime.dart';
import '../core/location/location_permission_service.dart';
import '../core/location/location_service.dart';
import '../core/notification/fcm_token_service.dart';
import '../core/notification/push_action_bridge.dart';
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
/// - background 계열: geofence 감시는 유지하고 SSE만 중지
class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  static final Logger _logger = Logger();

  late final Future<void> _bootstrapFuture;
  final PushActionBridge _pushActionBridge = PushActionBridge();
  StreamSubscription<Map<String, String>>? _pushActionSubscription;
  StreamSubscription<RemoteMessage>? _fcmTapSubscription;
  bool _initialPushTapHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _bootstrapFuture = Future<void>.microtask(() async {
      try {
        // FCM 토큰 초기화는 앱 시작 시점에 1회 수행합니다.
        await ref.read(fcmTokenServiceProvider).initialize();

        // 푸시 알림 탭 딥링크 라우팅 초기화
        await _initFcmTapDeepLinkRouting();

        // iOS 액션 버튼 브리지 초기화
        await _pushActionBridge.initialize();
        _pushActionSubscription =
            _pushActionBridge.events.listen(_handlePushActionEvent);
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

    final fcmTapSubscription = _fcmTapSubscription;
    if (fcmTapSubscription != null) {
      unawaited(fcmTapSubscription.cancel());
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
        await runtime.pauseRealtimeSync();
        break;
    }
  }

  /// FCM 푸시 알림 탭 딥링크 라우팅을 초기화합니다.
  ///
  /// 처리 대상:
  /// 1) 백그라운드 상태에서 푸시 탭 후 앱 복귀: onMessageOpenedApp
  /// 2) 종료 상태에서 푸시 탭으로 앱 기동: getInitialMessage
  Future<void> _initFcmTapDeepLinkRouting() async {
    if (kIsWeb) {
      return;
    }

    _fcmTapSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleFcmPushTap(message, source: 'onMessageOpenedApp'),
      onError: (Object error, StackTrace stackTrace) {
        _logger.e(
          '[PUSH_TAP_LISTEN_ERROR] onMessageOpenedApp',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );

    if (_initialPushTapHandled) {
      return;
    }
    _initialPushTapHandled = true;

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await _handleFcmPushTap(initialMessage, source: 'getInitialMessage');
    }
  }

  /// 푸시 탭 메시지에서 todoId를 추출해 상세 화면으로 이동합니다.
  Future<void> _handleFcmPushTap(
    RemoteMessage message, {
    required String source,
  }) async {
    final rawTodoId = message.data['todoId']?.toString();
    final todoId = int.tryParse(rawTodoId ?? '');
    if (todoId == null) {
      _logger.w(
        '[PUSH_TAP_SKIP] missing/invalid todoId source=$source data=${message.data}',
      );
      return;
    }

    if (!mounted) {
      return;
    }

    // 라우터가 붙은 이후 프레임에서 push해야 안전합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.push('/todos/$todoId');
    });
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
      _logger.e(
        '[PUSH_ACTION_ERROR] failed action handling',
        error: e,
        stackTrace: st,
      );
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
