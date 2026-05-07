import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/geofence/geofence_runtime.dart';
import '../core/notification/fcm_token_service.dart';
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
  late final Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _bootstrapFuture = Future<void>.microtask(() async {
      try {
        // FCM 토큰 초기화는 앱 시작 시점에 1회 수행합니다.
        await ref.read(fcmTokenServiceProvider).initialize();
      } catch (e) {
        debugPrint('Bootstrap skipped: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // lifecycle 콜백은 동기 메서드이므로, 내부에서 비동기 작업을 분리 실행합니다.
    unawaited(_handleLifecycle(state));
  }

  /// 앱 상태 전환에 맞춰 geofence 런타임을 제어합니다.
  Future<void> _handleLifecycle(AppLifecycleState state) async {
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
        // background 전환 시에는 SSE 연결/감시 리소스를 정리합니다.
        await runtime.stop();
        break;
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
